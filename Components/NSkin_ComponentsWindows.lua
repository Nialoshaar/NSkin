local _, NSkin = ...

local COMPONENT_STATE = "components"

local function GetWindowPixelEdgeOffsets(anchor)
    if not anchor then return 0, 0, 0, 0 end
    return NSkin:GetPhysicalPixelEdgeOffsets(anchor)
end

local function LayoutWindowHeaderBackground(frame, data, anchor)
    local background = data and data.windowHeaderBackground
    if not background or not anchor then return end

    local leftOffset, rightOffset, topOffset =
        GetWindowPixelEdgeOffsets(anchor)
    local requestedHeight = tonumber(data.windowHeaderRequestedHeight)
        or tonumber(data.windowHeaderHeight) or 0
    local height = requestedHeight > 0
        and NSkin:SnapToPhysicalPixel(frame, requestedHeight) or 0

    background:ClearAllPoints()
    background:SetPoint("TOPLEFT", anchor, "TOPLEFT",
        leftOffset, topOffset)
    background:SetPoint("TOPRIGHT", anchor, "TOPRIGHT",
        rightOffset, topOffset)
    if height > 0 then background:SetHeight(height) end

    data.windowHeaderHeight = height
    data.windowHeaderAnchor = anchor
end

local function LayoutWindowBackground(frame, data, anchor)
    local background = data and data.windowBackground
    if not background or not anchor then return end

    local leftOffset, rightOffset, topOffset, bottomOffset =
        GetWindowPixelEdgeOffsets(anchor)
    local headerHeight = tonumber(data.windowHeaderHeight) or 0
    local insetHeader = anchor == frame and headerHeight > 0

    background:ClearAllPoints()
    if insetHeader then
        background:SetPoint("TOPLEFT", frame, "TOPLEFT",
            leftOffset, topOffset - headerHeight)
        background:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT",
            rightOffset, bottomOffset)
    else
        background:SetPoint("TOPLEFT", anchor, "TOPLEFT",
            leftOffset, topOffset)
        background:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT",
            rightOffset, bottomOffset)
    end

    data.windowBackgroundLayoutAnchor = anchor
    data.windowBackgroundInsetHeader = insetHeader
    data.windowBackgroundLayoutHeight = headerHeight
end

local function RefreshWindowPixelGeometry(frame)
    local data = NSkin:GetSkinData(frame, COMPONENT_STATE, false)
    if not data then return end
    if data.windowHeaderBackground then
        LayoutWindowHeaderBackground(
            frame, data, data.windowHeaderAnchor or frame)
    end
    if data.windowBackground then
        LayoutWindowBackground(
            frame, data, data.windowBackgroundAnchor or frame)
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
    local function Conceal(owner, key, preserveKey)
        preserveKey = preserveKey or key
        if owner and (not preserveArtwork
            or preserveArtwork[preserveKey] ~= true)
        then
            ConcealWindowRegion(owner[key])
        end
    end
    for _, key in ipairs({
        "NineSlice",
        "Bg",
        "TopTileStreaks",
        "TitleBg",
        "PortraitContainer",
        "portrait",
        "portraitFrame",
        "topBorderBar",
        "topLeftCorner",
        "LeftEdge", "TopEdge", "RightEdge", "BottomEdge",
        "TopLeft", "TopRight", "BottomLeft", "BottomRight",
        "TopLeftCorner", "TopRightCorner",
        "BottomLeftCorner", "BottomRightCorner",
    }) do
        Conceal(frame, key)
    end

    -- InsetFrameTemplate decorations are conventional window artwork, but
    -- the inset itself may own functional children. Conceal only its named
    -- background and border regions. The global-name fallback supports older
    -- Blizzard windows that expose "$parentInset" without a parentKey.
    local frameName = frame.GetName and frame:GetName()
    local inset = frame.Inset or frame.InsetFrame
        or (frameName and _G[frameName .. "Inset"])
    if inset and (not preserveArtwork or preserveArtwork.Inset ~= true) then
        Conceal(inset, "Bg", "InsetBg")
        local nineSlice = inset.NineSlice
        Conceal(inset, "NineSlice", "InsetNineSlice")
        for _, key in ipairs({
            "LeftEdge", "TopEdge", "RightEdge", "BottomEdge",
            "TopLeft", "TopRight", "BottomLeft", "BottomRight",
            "TopLeftCorner", "TopRightCorner",
            "BottomLeftCorner", "BottomRightCorner",
        }) do
            Conceal(inset, key, "Inset" .. key)
            Conceal(nineSlice, key, "Inset" .. key)
        end
    end
end

function NSkin:SkinWindow(frame, backgroundAnchor, style, borderColor,
    backgroundOwner, preserveArtwork, borderOwner, borderAnchor)
    if not frame then return nil end

    local data = self:GetSkinData(frame, COMPONENT_STATE)
    self:ConcealWindowArtwork(frame, preserveArtwork)
    style = style or self:GetStyle("window")
    local anchor = backgroundAnchor or frame
    backgroundOwner = backgroundOwner or frame
    borderOwner = borderOwner or frame
    local background = data.windowBackground
    if background and data.windowBackgroundOwner ~= backgroundOwner then
        background:Hide()
        background = nil
    end
    if not background then
        background = backgroundOwner:CreateTexture(
            nil, "BACKGROUND", nil, 0)
        data.windowBackground = background
        data.windowBackgroundLayoutAnchor = nil
    end
    self:ConfigureOwnedPixelTexture(background)
    data.windowBackgroundOwner = backgroundOwner
    data.windowBackgroundAnchor = anchor
    LayoutWindowBackground(frame, data, anchor)
    self:RegisterPhysicalPixelRefresh(
        frame, "windowSurfaces", RefreshWindowPixelGeometry)
    local backgroundColor = self:GetResolvedAppearanceColor(style, "background")
    self:SetOwnedTextureColor(background, unpack(backgroundColor))
    data.windowBackgroundColor = {
        backgroundColor[1], backgroundColor[2], backgroundColor[3], backgroundColor[4],
    }

    if data.windowBorderOwner and data.windowBorderOwner ~= borderOwner then
        self:SetPixelBorderShown(self:GetPixelBorder(
            data.windowBorderOwner, "NSkinWindowBorder"), false)
    end
    data.windowBorderOwner = borderOwner
    local border = self:CreatePixelBorder(
        borderOwner, "NSkinWindowBorder", style.borderSize,
        borderColor or self:GetWindowBorderColor(), false, borderAnchor or anchor
    )
    self:SetPixelBorderSize(border, style.borderSize)
    self:SetPixelBorderPadding(border, style.borderPadding or 0)
    self:SetPixelBorderColor(border, unpack(borderColor or self:GetWindowBorderColor()))
    return background, border
end

function NSkin:SkinWindowHeader(frame, style, owner, defaultHeight, anchor)
    if not frame then return nil end

    style = style or self:GetStyle("window").header
    local data = self:GetSkinData(frame, COMPONENT_STATE)
    owner = owner or frame
    anchor = anchor or frame
    local background = data.windowHeaderBackground
    if background and data.windowHeaderOwner ~= owner then
        background:Hide()
        background = nil
    end
    if not background then
        background = owner:CreateTexture(nil, "BACKGROUND", nil, 7)
        data.windowHeaderBackground = background
        data.windowHeaderOwner = owner
        data.windowHeaderAnchor = nil
    end
    self:ConfigureOwnedPixelTexture(background)
    local height = tonumber(style.height)
        or tonumber(defaultHeight)
        or (frame.nskinOwnedGeometry and 22 or nil)
    data.windowHeaderRequestedHeight = height and math.max(0, height) or 0
    data.windowHeaderAnchor = anchor
    LayoutWindowHeaderBackground(frame, data, anchor)
    self:RegisterPhysicalPixelRefresh(
        frame, "windowSurfaces", RefreshWindowPixelGeometry)
    local color = style.matchBackground and data.windowBackgroundColor
        or self:GetResolvedAppearanceColor(style, "background")
    color = color or self:GetResolvedAppearanceColor(style, "background")
    self:SetOwnedTextureColor(background, unpack(color))
    LayoutWindowBackground(frame, data, data.windowBackgroundAnchor or frame)
    return background
end

local function RefreshGlyphButtonAppearance(button)
    local data = NSkin:GetSkinData(button, COMPONENT_STATE, false)
    local state = data and data.glyphButton
    if not state or not state.centeredGlyph then return end

    local enabled = not button.IsEnabled or button:IsEnabled()
    local alpha = enabled and 1 or state.disabledAlpha
    local color = state.contentColor
    NSkin:SetCenteredButtonGlyphColor(state.centeredGlyph, {
        color[1], color[2], color[3], (color[4] or 1) * alpha,
    })
    if not enabled and data.hoverGlow then data.hoverGlow:Hide() end
end

local function GetGlyphButtonBorderCenterOffset(button, border)
    if not button or not border or not border.left or not border.right
        or not border.top or not border.bottom
    then
        return nil
    end

    -- Border refresh callbacks and glyph refresh callbacks share the same
    -- ancestor lifecycle. Resnap here so the coordinates below always describe
    -- the current rendered border, regardless of callback iteration order.
    NSkin:ResnapPixelBorder(border)

    local centerX, centerY = button:GetCenter()
    local left = border.left:GetRight()
    local right = border.right:GetLeft()
    local top = border.top:GetBottom()
    local bottom = border.bottom:GetTop()
    if not centerX or not centerY or not left or not right
        or not top or not bottom
    then
        return nil
    end

    return (left + right) / 2 - centerX,
        (top + bottom) / 2 - centerY
end

function NSkin:SkinGlyphButton(button, options)
    if not button or not button.CreateTexture then return nil end
    options = options or {}

    local style = options.style or self:GetStyle("button")
    local backgroundKey = options.backgroundKey or "NSkinFlatBackground"
    local background = self:GetFlatBackground(button, backgroundKey)
    if not background then self:HideTextureRegions(button) end
    self:CreateFlatBackground(
        button, backgroundKey,
        options.background
            or self:GetResolvedAppearanceColor(style, "background")
            or style.background,
        options.border
            or self:GetResolvedAppearanceColor(style, "border")
            or self:GetComponentBorderColor("button", style))
    self:CreateFlatButtonGlow(button, style.hoverAlpha)

    local border = self:GetPixelBorder(button, backgroundKey .. "Border")
    if border then
        self:SetPixelBorderSize(border,
            tonumber(options.borderSize) or tonumber(style.borderSize) or 1)
        self:SetPixelBorderPadding(border,
            tonumber(options.borderPadding) or tonumber(style.borderPadding) or 0)
        self:SetPixelBorderShown(border, true)
    end

    local data = self:GetSkinData(button, COMPONENT_STATE)
    local state = data.glyphButton or {}
    data.glyphButton = state
    state.border = border
    state.contentColor = self:GetResolvedAppearanceColor(style, "text")
        or style.text or self:GetStyle("text").color
    state.disabledAlpha = tonumber(style.disabledTextAlpha) or 0.45

    local definition = {
        centerProvider = function(target)
            return GetGlyphButtonBorderCenterOffset(target, border)
        end,
        size = tonumber(options.size) or tonumber(style.textSize),
        thickness = tonumber(options.thickness),
        offsetX = tonumber(options.offsetX) or 0,
        offsetY = tonumber(options.offsetY) or 0,
    }
    if options.glyph then
        definition.glyph = options.glyph
    elseif options.icon then
        local iconDefinition = type(options.icon) == "table"
            and options.icon or { texture = options.icon }
        definition.texture = iconDefinition.texture
        definition.atlas = iconDefinition.atlas
        definition.size = tonumber(iconDefinition.size) or definition.size
        definition.rotation = tonumber(iconDefinition.rotation) or 0
        definition.offsetX = tonumber(iconDefinition.offsetX)
            or definition.offsetX
        definition.offsetY = tonumber(iconDefinition.offsetY)
            or definition.offsetY
    else
        return nil
    end

    state.centeredGlyph = self:CreateCenteredButtonGlyph(
        button, options.glyphKey or "glyphButton", definition)
    if state.centeredGlyph then
        self:SetCenteredButtonGlyphShown(state.centeredGlyph, true)
    end

    if not state.stateHooked and button.HookScript then
        button:HookScript("OnEnable", RefreshGlyphButtonAppearance)
        button:HookScript("OnDisable", RefreshGlyphButtonAppearance)
        button:HookScript("OnShow", RefreshGlyphButtonAppearance)
        state.stateHooked = true
    end
    RefreshGlyphButtonAppearance(button)
    return state
end

local function CaptureButtonNativeDefaults(button)
    local data = NSkin:GetSkinData(button, COMPONENT_STATE)
    local state = data.canonicalButtonDefaults
    if state then return state end

    state = {}
    data.canonicalButtonDefaults = state
    if button.GetSize then
        local width, height = button:GetSize()
        state.width = tonumber(width)
        state.height = tonumber(height)
    end

    local text = button.GetText and button:GetText()
    if type(text) == "string" and text ~= "" then
        state.content = { type = "TEXT", text = text }
    end

    if not state.content and button.GetNormalTexture then
        local texture = button:GetNormalTexture()
        if texture then
            local atlas = texture.GetAtlas and texture:GetAtlas()
            local path = texture.GetTexture and texture:GetTexture()
            if atlas then
                state.content = { type = "ATLAS", atlas = atlas }
            elseif path then
                state.content = { type = "ICON", texture = path }
            end
        end
    end

    state.content = state.content or { type = "TEXT", text = "" }
    return state
end

local function ResolveCanonicalButtonContent(button, style, options)
    local native = CaptureButtonNativeDefaults(button)
    local default = options.defaultContent or native.content
    local mode = string.upper(tostring(style.contentMode or "DEFAULT"))
    if mode == "DEFAULT" then
        local resolved = {}
        for key, value in pairs(default or {}) do resolved[key] = value end
        resolved.type = string.upper(tostring(resolved.type or "TEXT"))
        if resolved.type == "GLYPH"
            and type(style.contentGlyph) == "string"
            and style.contentGlyph ~= ""
        then
            resolved.glyph = style.contentGlyph
        end
        return resolved
    end

    if mode == "TEXT" then
        local text = style.contentText
        if type(text) ~= "string" or text == "" then
            text = default and default.text
                or (button.GetText and button:GetText()) or ""
        end
        return { type = "TEXT", text = text }
    elseif mode == "GLYPH" then
        local glyph = type(style.contentGlyph) == "string"
            and style.contentGlyph ~= "" and style.contentGlyph
            or (default and default.glyph) or "close"
        return {
            type = "GLYPH",
            glyph = glyph,
        }
    elseif mode == "ICON" then
        return {
            type = "ICON",
            texture = style.contentTexture ~= "" and style.contentTexture
                or (default and default.texture),
        }
    elseif mode == "ATLAS" then
        return {
            type = "ATLAS",
            atlas = style.contentAtlas ~= "" and style.contentAtlas
                or (default and default.atlas),
        }
    end
    return default or native.content
end

function NSkin:SkinButton(button, options)
    if not button then return nil end
    options = options or {}
    local style = options.style or self:GetStyle("button")
    local native = CaptureButtonNativeDefaults(button)
    local data = self:GetSkinData(button, COMPONENT_STATE)

    local width = tonumber(style.width)
    local height = tonumber(style.height)
    if button.SetSize and native.width and native.height then
        local resolvedWidth = width and width > 0 and width or native.width
        local resolvedHeight = height and height > 0 and height or native.height
        if resolvedWidth > 0 and resolvedHeight > 0 then
            button:SetSize(resolvedWidth, resolvedHeight)
        end
    end

    local content = ResolveCanonicalButtonContent(button, style, options)
    local contentType = string.upper(tostring(content and content.type or "TEXT"))
    local contentSize = tonumber(style.contentSize)
    if not contentSize or contentSize <= 0 then
        contentSize = tonumber(content and content.size)
            or tonumber(options.textSize)
            or tonumber(style.textSize)
    end
    local offsetX = tonumber(style.contentOffsetX) or 0
    local offsetY = tonumber(style.contentOffsetY) or 0
    local border = options.border
        or self:GetResolvedAppearanceColor(style, "border")
        or self:GetComponentBorderColor("button", style)
    local background = options.background
        or self:GetResolvedAppearanceColor(style, "background")
        or style.background

    if contentType == "TEXT" then
        if data.glyphButton and data.glyphButton.centeredGlyph then
            self:SetCenteredButtonGlyphShown(
                data.glyphButton.centeredGlyph, false)
        end
        self:SkinActionButton(button, {
            style = style,
            border = border,
            background = background,
            borderSize = style.borderSize,
            borderPadding = style.borderPadding,
            textSize = contentSize,
            label = content.text or "",
            labelOffsetX = offsetX,
            labelOffsetY = offsetY,
            customText = string.upper(tostring(style.contentMode or "DEFAULT"))
                == "TEXT",
            textRegion = options.textRegion,
            preserveTexture = options.preserveTexture,
            preserveTextGeometry = options.preserveTextGeometry,
            disabledTextAlpha = options.disabledTextAlpha,
        })
        return self:GetSkinData(button, COMPONENT_STATE)
    end

    data.actionActive = nil
    if data.label then data.label:Hide() end

    local glyphOptions = {
        style = style,
        border = border,
        background = background,
        borderSize = style.borderSize,
        borderPadding = style.borderPadding,
        size = contentSize,
        offsetX = offsetX,
        offsetY = offsetY,
        backgroundKey = options.backgroundKey,
        glyphKey = options.glyphKey or "buttonContent",
    }
    if contentType == "GLYPH" then
        glyphOptions.glyph = content.glyph or "close"
    elseif contentType == "ATLAS" then
        if not content.atlas then return nil end
        glyphOptions.icon = { atlas = content.atlas, size = contentSize }
    else
        if not content.texture then return nil end
        glyphOptions.icon = { texture = content.texture, size = contentSize }
    end
    return self:SkinGlyphButton(button, glyphOptions)
end

local STANDARD_WINDOW_HEADER_GLYPHS = {
    close = { glyph = "close" },
    maximize = { glyph = "plus" },
    minimize = { glyph = "minus" },
    fullscreen = { glyph = "square" },
}

local function RefreshWindowHeaderButtonAppearance(button)
    local data = NSkin:GetSkinData(button, COMPONENT_STATE, false)
    local state = data and data.windowHeaderButton
    if not state then return end

    local enabled = not button.IsEnabled or button:IsEnabled()
    local alpha = enabled and 1 or state.disabledAlpha
    local color = state.contentColor
    if state.centeredGlyph then
        NSkin:SetCenteredButtonGlyphColor(state.centeredGlyph, {
            color[1], color[2], color[3], (color[4] or 1) * alpha,
        })
    end
    if not enabled and data.hoverGlow then data.hoverGlow:Hide() end
end

function NSkin:SkinWindowHeaderButton(button, content, options)
    if not button or type(content) ~= "table" then return nil end
    options = options or {}

    local glyph = content.glyph
        and STANDARD_WINDOW_HEADER_GLYPHS[content.glyph]
    local glyphOptions = {
        style = options.style,
        background = options.background,
        border = options.border,
        borderSize = options.borderSize,
        borderPadding = options.borderPadding,
        size = tonumber(content.size),
        thickness = tonumber(content.thickness),
        offsetX = tonumber(content.offsetX) or 0,
        offsetY = tonumber(content.offsetY) or 0,
        glyphKey = "windowHeader",
    }
    if glyph then
        glyphOptions.glyph = glyph.glyph
    elseif content.icon then
        glyphOptions.icon = content.icon
    else
        return nil
    end

    local defaultContent
    if glyphOptions.glyph then
        defaultContent = {
            type = "GLYPH",
            glyph = glyphOptions.glyph,
            size = glyphOptions.size,
        }
    elseif glyphOptions.icon then
        local icon = glyphOptions.icon
        defaultContent = {
            type = type(icon) == "table" and icon.atlas and "ATLAS" or "ICON",
            atlas = type(icon) == "table" and icon.atlas or nil,
            texture = type(icon) == "table" and icon.texture or icon,
            size = type(icon) == "table" and icon.size or glyphOptions.size,
        }
    end
    local state = self:SkinButton(button, {
        style = glyphOptions.style,
        background = glyphOptions.background,
        border = glyphOptions.border,
        borderSize = glyphOptions.borderSize,
        borderPadding = glyphOptions.borderPadding,
        defaultContent = defaultContent,
        glyphKey = glyphOptions.glyphKey,
    })
    local data = self:GetSkinData(button, COMPONENT_STATE)
    data.windowHeaderButton = state
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

    if options.preserveGeometry ~= true then
        closeButton:ClearAllPoints()
        closeButton:SetPoint("TOPRIGHT", window, "TOPRIGHT", 0, 0)
    end
    -- PreserveGeometry protects Blizzard's anchor relationship, not a user
    -- requested size override. Size remains independently customizable.
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
    self:SetPixelBorderPadding(border, options.borderPadding or 0)
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

local function ConfigureWindowHeaderControlBorder(
    control, borderSize, borderPadding)
    local border = NSkin:GetPixelBorder(
        control, "NSkinFlatBackgroundBorder")
    if not border then return end

    NSkin:SetPixelBorderSize(border, borderSize or 1)
    NSkin:SetPixelBorderPadding(border, borderPadding or 0)
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
                    target, definition.borderSize, definition.borderPadding)
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
        definition.backgroundOwner, definition.preserveArtwork,
        definition.borderOwner, definition.borderAnchor)

    local closeButton = definition.closeButton
    if closeButton == nil then closeButton = frame.CloseButton end
    local headerHeight = tonumber(definition.headerHeight)
    if not headerHeight and closeButton and closeButton.GetHeight then
        local closeHeight = tonumber(closeButton:GetHeight())
        if closeHeight and closeHeight > 0 then headerHeight = closeHeight end
    end
    local header = self:SkinWindowHeader(frame, style.header,
        definition.headerOwner, headerHeight,
        definition.headerAnchor)

    local title = definition.title
    if title == nil then
        title = frame.TitleContainer and frame.TitleContainer.TitleText
    end
    if title then
        self:SetFontStringColor(title, unpack(
            self:GetResolvedAppearanceColor(style.header, "text")))
        self:ApplyResolvedTypography(title, style.header)
    end

    if closeButton and definition.skinCloseButton ~= false then
        local headerControlsID = definition.headerControlsID
            or (elementID .. ".HeaderControls")
        local headerButtonStyle = self:GetAppearanceStyle(
            "button", appearanceWindowID, headerControlsID)
        local headerButtonBorder = self:GetAppearanceBorderColor(
            "button", headerButtonStyle,
            appearanceWindowID, headerControlsID)
        local buttonWidth = tonumber(headerButtonStyle.width)
        local buttonHeight = tonumber(headerButtonStyle.height)
        buttonWidth = buttonWidth and buttonWidth > 0 and buttonWidth or nil
        buttonHeight = buttonHeight and buttonHeight > 0 and buttonHeight or nil
        self:SkinStandardCloseButton(frame, closeButton, {
            style = headerButtonStyle,
            background = definition.closeButtonBackground,
            border = definition.closeButtonBorder or headerButtonBorder,
            borderSize = headerButtonStyle.borderSize,
            borderPadding = headerButtonStyle.borderPadding,
            width = buttonWidth,
            height = buttonHeight,
            preserveGeometry = definition.preserveCloseButtonGeometry,
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
            borderSize = headerButtonStyle.borderSize,
            borderPadding = headerButtonStyle.borderPadding,
        })
        -- Register on every chrome application so an existing runtime element
        -- keeps the current direct chrome definition and refresh contract.
        -- RegisterSkinningElement updates existing definitions in place.
        self:RegisterSkinningElement(headerControlsID, {
            label = definition.headerControlsLabel
                or "Window header buttons",
            kind = "BUTTON",
            appearanceWindowID = appearanceWindowID,
            editorOptions = self:CreateEditorOptionsPreset("BUTTON"),
            appearanceStyles = { "button" },
            appearanceTypeIDs = { "BUTTON" },
            window = frame,
            target = closeButton,
            chromeDefinition = definition,
            priority = 95,
            draggable = false,
            highlightRegions = function()
                return NSkin:GetWindowHeaderControlRegions(
                    frame, headerControlsID)
            end,
            isEditable = function()
                return frame:IsVisible() and closeButton:IsVisible()
            end,
            refreshAppearance = function(_, element)
                return NSkin:RefreshWindowHeaderControlsElement(element)
            end,
            refreshLayout = function(_, element)
                return NSkin:RefreshWindowHeaderControlsElement(element)
            end,
        })
        self:NotifySkinningElementBoundsChanged(headerControlsID)
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

function NSkin:RefreshWindowHeaderControlsElement(element)
    if not element or not element.window then return false end
    local definition = element.chromeDefinition
    if not definition then
        local data = self:GetSkinData(element.window, COMPONENT_STATE, false)
        definition = data and data.standardWindowChromeDefinition
    end
    if type(definition) ~= "table" or not definition.frame then return false end

    local frame = definition.frame
    local closeButton = definition.closeButton
    if closeButton == nil then closeButton = frame.CloseButton end
    if not closeButton or definition.skinCloseButton == false then return false end

    local appearanceWindowID = definition.appearanceWindowID
    local elementID = definition.elementID
    local headerControlsID = definition.headerControlsID
        or (elementID .. ".HeaderControls")
    local windowStyle = definition.style or self:GetAppearanceStyle(
        "window", appearanceWindowID, elementID)
    local headerButtonStyle = self:GetAppearanceStyle(
        "button", appearanceWindowID, headerControlsID)
    if not windowStyle or not headerButtonStyle then return false end

    local headerButtonBorder = self:GetAppearanceBorderColor(
        "button", headerButtonStyle,
        appearanceWindowID, headerControlsID)
    local buttonWidth = tonumber(headerButtonStyle.width)
    local buttonHeight = tonumber(headerButtonStyle.height)
    buttonWidth = buttonWidth and buttonWidth > 0 and buttonWidth or nil
    buttonHeight = buttonHeight and buttonHeight > 0 and buttonHeight or nil

    self:SkinStandardCloseButton(frame, closeButton, {
        style = headerButtonStyle,
        background = definition.closeButtonBackground,
        border = definition.closeButtonBorder or headerButtonBorder,
        borderSize = headerButtonStyle.borderSize,
        borderPadding = headerButtonStyle.borderPadding,
        width = buttonWidth,
        height = buttonHeight,
        preserveGeometry = definition.preserveCloseButtonGeometry,
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
        borderSize = headerButtonStyle.borderSize,
        borderPadding = headerButtonStyle.borderPadding,
    })

    self:NotifySkinningElementBoundsChanged(element.id)
    self:ResnapPixelBordersForElement(element)
    return true
end

local function CanModifyBackgroundRegion(region)
    return region and not (region.IsForbidden and region:IsForbidden())
        and not (region.IsProtected and region:IsProtected() and InCombatLockdown())
end

local function SetNativeBackgroundShown(state, region, shown)
    if not CanModifyBackgroundRegion(region) then return end
    state.applying = true
    region:SetShown(shown)
    state.applying = nil
end

-- The native source remains authoritative for texture/atlas, alpha, crop and
-- layout. Only visibility is owned while replacing it. In particular, Default
-- must reveal the current native atlas, not a snapshot from an earlier page/spec.
function NSkin:ApplyTextureBackground(owner, definition, settings)
    local source = definition and definition.source
    if not CanModifyBackgroundRegion(owner) or not CanModifyBackgroundRegion(source) then return false end
    local state = self:GetSkinData(owner, "textureBackground:" .. definition.id)
    local mode = settings and settings.mode or "DEFAULT"
    if mode ~= "DEFAULT" and mode ~= "NONE" and mode ~= "CUSTOM" then mode = "DEFAULT" end
    state.mode, state.active = mode, true
    state.regions = state.regions or {}
    local regions = { source }
    for _, region in ipairs(definition.regions or {}) do regions[#regions + 1] = region end
    local current = {}
    for _, region in ipairs(regions) do
        if CanModifyBackgroundRegion(region) then
            current[region] = true
            local native = state.regions[region]
            if not native then
                native = { shown = region:IsShown() }
                state.regions[region] = native
                -- Record only visibility authored outside this helper. Hidden
                -- native layers may still animate; hiding them avoids overriding
                -- their alpha, animation state, or current atlas.
                local function NativeVisibility(shown)
                    if state.applying then return end
                    native.shown = shown
                    if native.active and state.active and state.mode ~= "DEFAULT" then
                        SetNativeBackgroundShown(state, region, false)
                    end
                    if native.active and region == source and state.texture and state.active and state.mode == "CUSTOM" then
                        state.texture:SetShown(state.loaded and shown)
                    end
                end
                hooksecurefunc(region, "Show", function() NativeVisibility(true) end)
                hooksecurefunc(region, "Hide", function() NativeVisibility(false) end)
                hooksecurefunc(region, "SetShown", function(_, shown) NativeVisibility(shown == true) end)
            end
            native.active = true
            SetNativeBackgroundShown(state, region, mode == "DEFAULT" and native.shown)
        end
    end
    for region, native in pairs(state.regions) do
        if not current[region] and native.active then
            native.active = nil
            SetNativeBackgroundShown(state, region, native.shown)
        end
    end
    if state.texture then state.texture:Hide() end
    state.loaded = false
    if mode == "CUSTOM" and type(settings.path) == "string" and settings.path ~= "" then
        if not state.texture then
            local layer, sublevel = source:GetDrawLayer()
            state.texture = owner:CreateTexture(nil, layer, nil, sublevel)
        end
        state.texture:ClearAllPoints()
        state.texture:SetAllPoints(source)
        local ok, loaded = pcall(state.texture.SetTexture, state.texture, settings.path)
        state.loaded = ok and loaded == true
        state.texture:SetShown(state.loaded and state.regions[source].shown)
    end
    return true
end

function NSkin:RestoreTextureBackground(owner, id)
    if not CanModifyBackgroundRegion(owner) then return false end
    local state = self:GetSkinData(owner, "textureBackground:" .. id, false)
    if not state then return false end
    state.active = nil
    if state.texture then state.texture:Hide() end
    for region, native in pairs(state.regions) do
        native.active = nil
        SetNativeBackgroundShown(state, region, native.shown)
    end
    return true
end
