local _, NSkin = ...

local COMPONENT_STATE = "components"
local SECTION_CARD_STATE = "sectionCardComponent"
local SECTION_CARD_BACKGROUND = "NSkinSectionCardBackground"
local SECTION_CARD_TEXT_STATE = "sectionCardTextAppearance"
local PROGRESS_COMPONENT_STATE = "progressBarComponent"
local PROGRESS_BACKGROUND_KEY = "NSkinProgressBarBackground"
local function ResolveSectionCardValue(value, target)
    if type(value) ~= "function" then return value end
    local ok, resolved = pcall(value, target)
    -- false is a valid collapsed state; only failed callbacks become unknown.
    if ok then return resolved end
    return nil
end

local function ResolveSectionCardExpanded(target, options)
    local expanded = options.expanded
    if type(expanded) == "function" then
        expanded = ResolveSectionCardValue(expanded, target)
    end
    if type(expanded) == "boolean" then return expanded end

    expanded = options.isExpanded
    if type(expanded) == "function" then
        expanded = ResolveSectionCardValue(expanded, target)
    end
    if type(expanded) == "boolean" then return expanded end

    if type(options.getExpanded) == "function" then
        expanded = ResolveSectionCardValue(options.getExpanded, target)
        if type(expanded) == "boolean" then return expanded end
    end

    if type(target.IsExpanded) == "function" then
        local ok, value = pcall(target.IsExpanded, target)
        if ok and type(value) == "boolean" then return value end
    end
    if type(target.isExpanded) == "boolean" then return target.isExpanded end
    if type(target.expanded) == "boolean" then return target.expanded end
    return nil
end

local function HideSectionCardArtwork(region)
    if not region or not region.GetObjectType then return end
    if region.SetAlpha then region:SetAlpha(0) end
    if region:GetObjectType() == "Texture" and region.SetTexture then
        region:SetTexture(nil)
    end
    if region.Hide then region:Hide() end
end

local function AddSectionCardPreservedRegion(regions, value)
    if not value then return end
    if value.GetObjectType then
        regions[value] = true
        return
    end
    if type(value) == "table" then
        for i = 1, #value do
            AddSectionCardPreservedRegion(regions, value[i])
        end
    end
end

local function SuppressSectionCardArtwork(target, options, icon,
    background, border, glow)
    local preserved = {}
    AddSectionCardPreservedRegion(preserved, icon)
    AddSectionCardPreservedRegion(preserved, options.preserveTextures)
    AddSectionCardPreservedRegion(preserved, background)
    AddSectionCardPreservedRegion(preserved, glow)
    if border then
        AddSectionCardPreservedRegion(preserved, border.top)
        AddSectionCardPreservedRegion(preserved, border.bottom)
        AddSectionCardPreservedRegion(preserved, border.left)
        AddSectionCardPreservedRegion(preserved, border.right)
    end

    -- Generic cards cannot know which Blizzard textures are decorative.  A
    -- window adapter opts into direct-region stripping only after auditing its
    -- row template, or supplies the exact artworkRegions it owns.
    if options.stripArtwork == true and target.GetRegions then
        for _, region in ipairs({ target:GetRegions() }) do
            if not preserved[region] and region.GetObjectType
                and region:GetObjectType() == "Texture"
            then
                HideSectionCardArtwork(region)
            end
        end
    end
    for _, region in ipairs(options.artworkRegions or {}) do
        if not preserved[region] then HideSectionCardArtwork(region) end
    end
end

local function ResolveSectionCardText(target, state, options)
    local textRegion = ResolveSectionCardValue(options.textRegion, target)
    local text = ResolveSectionCardValue(options.text, target)
    if not textRegion and text and text.GetObjectType
        and text:GetObjectType() == "FontString"
    then
        textRegion, text = text, nil
    end
    if not textRegion then
        textRegion = target.GetFontString and target:GetFontString()
            or target.Text or target.Label or target.Name
    end
    if not textRegion and type(text) == "string" and target.CreateFontString then
        if not state.ownedText then
            state.ownedText = target:CreateFontString(
                nil, "OVERLAY", "GameFontHighlight")
        end
        textRegion = state.ownedText
    end
    if textRegion and type(text) == "string" and textRegion.SetText then
        textRegion:SetText(text)
    end
    return textRegion
end

local function LayoutSectionCardText(target, textRegion, icon, style,
    collapsible)
    if not textRegion or not textRegion.ClearAllPoints
        or not textRegion.SetPoint
    then return end

    local offsetX = tonumber(style.textOffsetX) or 0
    local offsetY = tonumber(style.textOffsetY) or 0
    local iconSpacing = tonumber(style.iconSpacing) or 0
    textRegion:ClearAllPoints()
    if icon and icon.GetObjectType then
        textRegion:SetPoint("LEFT", icon, "RIGHT",
            offsetX + iconSpacing, offsetY)
    else
        textRegion:SetPoint("LEFT", target, "LEFT", offsetX, offsetY)
    end

    local rightInset = math.max(0, offsetX)
    if collapsible then
        rightInset = math.max(rightInset,
            math.max(0, -(tonumber(style.glyphOffsetX) or 0))
                + math.max(1, tonumber(style.glyphSize) or 14))
    end
    textRegion:SetPoint("RIGHT", target, "RIGHT", -rightInset, offsetY)
end

local function AnchorSectionCardSurface(region, visualRegion, inset)
    if not region or not visualRegion or not region.ClearAllPoints
        or not region.SetPoint
    then return end
    inset = tonumber(inset) or 0
    region:ClearAllPoints()
    region:SetPoint("TOPLEFT", visualRegion, "TOPLEFT", inset, -inset)
    region:SetPoint("BOTTOMRIGHT", visualRegion, "BOTTOMRIGHT", -inset, inset)
end

local function RefreshSectionCardGlyph(target)
    local state = NSkin:GetSkinData(target, SECTION_CARD_STATE, false)
    if not state or not state.glyph then return end
    if not state.collapsible then
        state.glyph:Hide()
        return
    end

    local expanded = ResolveSectionCardExpanded(target, state.options or {})
    if type(expanded) ~= "boolean" then
        state.glyph:Hide()
        return
    end
    state.glyph.vertical:SetShown(not expanded)
    state.glyph:Show()
end

local function EnforceSectionCardTextAppearance(textRegion)
    local data = NSkin:GetSkinData(
        textRegion, SECTION_CARD_TEXT_STATE, false)
    if not data or data.enforcing or not data.style then return end
    data.enforcing = true
    if data.color and textRegion.SetTextColor then
        textRegion:SetTextColor(unpack(data.color))
    end
    NSkin:ApplyResolvedTypography(textRegion, data.style)
    data.enforcing = nil
end

local function ConfigureSectionCardTextAppearance(textRegion, style, color)
    local data = NSkin:GetSkinData(textRegion, SECTION_CARD_TEXT_STATE)
    data.style = style
    data.color = { unpack(color) }
    if not data.colorHookInstalled and _G.hooksecurefunc
        and type(textRegion.SetTextColor) == "function"
    then
        _G.hooksecurefunc(textRegion, "SetTextColor", function(region)
            EnforceSectionCardTextAppearance(region)
        end)
        data.colorHookInstalled = true
    end
    EnforceSectionCardTextAppearance(textRegion)
end

local function RefreshSectionCardPresentation(target)
    local state = NSkin:GetSkinData(target, SECTION_CARD_STATE, false)
    if not state then return end
    if state.textRegion then
        EnforceSectionCardTextAppearance(state.textRegion)
    end
    RefreshSectionCardGlyph(target)
end

local function QueueSectionCardGlyphRefresh(target)
    local state = NSkin:GetSkinData(target, SECTION_CARD_STATE, false)
    if not state or state.glyphRefreshPending then return end
    state.glyphRefreshPending = true
    local function Refresh()
        local current = NSkin:GetSkinData(
            target, SECTION_CARD_STATE, false)
        if current then current.glyphRefreshPending = nil end
        RefreshSectionCardPresentation(target)
    end
    if C_Timer and C_Timer.After then C_Timer.After(0, Refresh) else Refresh() end
end

function NSkin:SkinSectionCard(target, options)
    if not target or not target.CreateTexture or not target.CreateFontString
        or (target.IsForbidden and target:IsForbidden())
    then return nil end

    options = options or {}
    local style = options.style or self:GetStyle("sectionCard")
    if not style then return nil end
    local state = self:GetSkinData(target, SECTION_CARD_STATE)
    state.options = options
    state.collapsible = options.collapsible == true
    local visualRegion = ResolveSectionCardValue(options.visualRegion, target)
    if not (visualRegion and visualRegion.GetObjectType) then
        visualRegion = target
    end
    state.visualRegion = visualRegion

    if not state.originalHeight and target.GetHeight then
        local originalHeight = target:GetHeight()
        state.originalHeight = tonumber(originalHeight) and originalHeight > 0
            and originalHeight or nil
    end
    local height = tonumber(options.height)
    if height == nil then height = tonumber(style.height) end
    if height and height > 0 and target.SetHeight then
        target:SetHeight(height)
        state.heightModified = true
    elseif state.heightModified and state.originalHeight and target.SetHeight then
        target:SetHeight(state.originalHeight)
        state.heightModified = nil
    end

    local backgroundColor = options.background
        or self:GetResolvedAppearanceColor(style, "background")
    local borderColor = options.border
        or self:GetComponentBorderColor("sectionCard", style)
    local background = self:CreateFlatBackground(
        target, SECTION_CARD_BACKGROUND, backgroundColor, borderColor)
    AnchorSectionCardSurface(background, visualRegion, 1)
    local border = self:GetPixelBorder(
        target, SECTION_CARD_BACKGROUND .. "Border")
    if border then border.anchor = visualRegion end
    self:SetPixelBorderColor(border, unpack(borderColor))
    self:SetPixelBorderSize(border, style.borderSize or 1)
    self:SetPixelBorderPadding(border, style.borderPadding or 0)
    local glow = self:CreateFlatButtonGlow(target, style.hoverAlpha)
    AnchorSectionCardSurface(glow, visualRegion, 1)

    local icon = ResolveSectionCardValue(options.icon, target)
    SuppressSectionCardArtwork(
        target, options, icon, background, border, glow)

    local textRegion = ResolveSectionCardText(target, state, options)
    state.textRegion = textRegion
    if textRegion and textRegion.GetFont then
        ConfigureSectionCardTextAppearance(textRegion, style,
            self:GetResolvedAppearanceColor(style, "text"))
        if options.preserveTextLayout ~= true then
            LayoutSectionCardText(
                visualRegion, textRegion, icon, style, state.collapsible)
        end
    end

    if state.collapsible then
        if not state.glyph then
            local glyph = CreateFrame("Frame", nil, target)
            glyph.horizontal = glyph:CreateTexture(nil, "OVERLAY", nil, 7)
            glyph.vertical = glyph:CreateTexture(nil, "OVERLAY", nil, 7)
            self:ConfigureOwnedPixelTexture(glyph.horizontal)
            self:ConfigureOwnedPixelTexture(glyph.vertical)
            state.glyph = glyph
        end
        local glyph = state.glyph
        local glyphSize = math.max(1, tonumber(style.glyphSize) or 14)
        local strokeSize = math.max(1, math.floor(glyphSize / 7 + 0.5))
        glyph:SetSize(glyphSize, glyphSize)
        if glyph.SetFrameLevel and target.GetFrameLevel then
            glyph:SetFrameLevel(target:GetFrameLevel() + 10)
        end
        glyph:ClearAllPoints()
        glyph:SetPoint(
            "RIGHT",
            visualRegion,
            "RIGHT",
            tonumber(style.glyphOffsetX) or 0,
            tonumber(style.glyphOffsetY) or 0
        )
        local glyphColor = self:GetResolvedAppearanceColor(style, "glyph")
        glyph.horizontal:ClearAllPoints()
        glyph.horizontal:SetPoint("LEFT", glyph, "LEFT", 0, 0)
        glyph.horizontal:SetPoint("RIGHT", glyph, "RIGHT", 0, 0)
        glyph.horizontal:SetHeight(strokeSize)
        glyph.horizontal:SetColorTexture(unpack(glyphColor))
        glyph.vertical:ClearAllPoints()
        glyph.vertical:SetPoint("TOP", glyph, "TOP", 0, 0)
        glyph.vertical:SetPoint("BOTTOM", glyph, "BOTTOM", 0, 0)
        glyph.vertical:SetWidth(strokeSize)
        glyph.vertical:SetColorTexture(unpack(glyphColor))
    elseif state.glyph then
        state.glyph:Hide()
    end

    if not state.presentationHooksInstalled and target.HookScript then
        for _, script in ipairs({ "OnShow", "OnEnter", "OnLeave" }) do
            target:HookScript(script, RefreshSectionCardPresentation)
        end
        state.presentationHooksInstalled = true
    end
    if not state.titleColorHookInstalled and _G.hooksecurefunc
        and type(target.CheckHighlightTitle) == "function"
    then
        local hooked = pcall(_G.hooksecurefunc, target,
            "CheckHighlightTitle", RefreshSectionCardPresentation)
        state.titleColorHookInstalled = hooked == true
    end
    if state.collapsible and not state.expansionHooksInstalled then
        if target.HookScript and target.HasScript
            and target:HasScript("OnClick")
        then
            target:HookScript("OnClick", QueueSectionCardGlyphRefresh)
        end
        if _G.hooksecurefunc then
            for _, method in ipairs({
                "SetExpanded", "SetCollapsed", "UpdateCollapsedState",
            }) do
                if type(target[method]) == "function" then
                    pcall(_G.hooksecurefunc, target, method, function()
                        QueueSectionCardGlyphRefresh(target)
                    end)
                end
            end
        end
        state.expansionHooksInstalled = true
    end
    RefreshSectionCardPresentation(target)
    return state
end

local ICON_COMPONENT_STATE = "iconComponent"
local ICON_BORDER_KEY = "NSkinIconBorder"

function NSkin:GetIconTexCoords(width, height, zoom, crop)
    width = math.max(tonumber(width) or 1, 0.001)
    height = math.max(tonumber(height) or 1, 0.001)
    zoom = math.max(0, math.min(0.49, tonumber(zoom) or 0))
    crop = math.max(0.01, math.min(1, tonumber(crop) or 1))

    local cropInset = (1 - crop) / 2
    local cropSpan = 1 - (cropInset * 2)
    local visibleSpan = (1 - (zoom * 2)) * cropSpan
    local horizontalSpan, verticalSpan = visibleSpan, visibleSpan
    local aspect = width / height
    if aspect > 1 then
        verticalSpan = visibleSpan / aspect
    elseif aspect < 1 then
        horizontalSpan = visibleSpan * aspect
    end

    local left = (1 - horizontalSpan) / 2
    local top = (1 - verticalSpan) / 2
    return left, 1 - left, top, 1 - top
end

local function ResolveIconTexture(target, options)
    if options.texture then return options.texture end
    if target and target.GetObjectType and target:GetObjectType() == "Texture" then
        return target
    end
    return target and (target.Icon or target.icon or target.iconTexture)
end

local ICON_SHAPES = {
    square = {
        applyTexCoords = function(texture, width, height, zoom, crop)
            texture:SetTexCoord(NSkin:GetIconTexCoords(
                width, height, zoom, crop))
        end,
    },
}

local function ApplyIconTexCoords(target)
    local data = NSkin:GetSkinData(target, ICON_COMPONENT_STATE, false)
    local texture = data and data.texture
    if not texture or not texture.SetTexCoord then return end
    local width = texture.GetWidth and texture:GetWidth() or data.width
    local height = texture.GetHeight and texture:GetHeight() or data.height
    local shape = ICON_SHAPES[data.shape] or ICON_SHAPES.square
    shape.applyTexCoords(texture, width, height, data.zoom, data.crop)
end

function NSkin:SkinIcon(target, options)
    if not target then return false end
    options = options or {}
    local texture = ResolveIconTexture(target, options)
    if not texture or not texture.SetTexCoord then return false end

    local owner = options.borderOwner
        or (target.GetObjectType and target:GetObjectType() ~= "Texture"
            and target)
        or (texture.GetParent and texture:GetParent())
    if not owner or not owner.CreateTexture then return false end

    local data = self:GetSkinData(target, ICON_COMPONENT_STATE)
    local textureData = self:GetSkinData(texture, ICON_COMPONENT_STATE)
    local borderKey = options.borderKey or (owner == target
        and ICON_BORDER_KEY
        or (ICON_BORDER_KEY .. ":" .. tostring(texture)))
    if not textureData.baselineID then
        textureData.baselineID = "IconTexture:" .. tostring(texture)
        self:CaptureComponentBaseline(textureData.baselineID, texture, {
            size = true,
            texCoords = true,
        })
    end
    if options.reset == true then
        self:RestoreComponentBaseline(textureData.baselineID, {
            size = true,
            texCoords = true,
        })
        local oldBorder = self:GetPixelBorder(owner, borderKey)
        self:SetPixelBorderShown(oldBorder, false)
        return true
    end

    local style = options.style or self:GetStyle("icon")
    if not style then return false end
    local shape = string.lower(tostring(
        options.shape or style.shape or "square"))
    if not ICON_SHAPES[shape] then shape = "square" end

    data.texture = texture
    data.shape = shape
    data.zoom = tonumber(options.zoom)
        or tonumber(style.zoom) or 0
    data.crop = tonumber(options.crop)
        or tonumber(style.crop) or 1

    local width = tonumber(options.width) or tonumber(style.width)
    local height = tonumber(options.height) or tonumber(style.height)
    width = width and width > 0 and width or nil
    height = height and height > 0 and height or nil
    local baseline = self:GetComponentBaseline(textureData.baselineID)
    if width or height then
        self:MarkComponentGeometryModified(
            textureData.baselineID, "size", true)
        if width and texture.SetWidth then texture:SetWidth(width) end
        if height and texture.SetHeight then texture:SetHeight(height) end
    elseif baseline and baseline.modified.size then
        self:RestoreComponentBaseline(textureData.baselineID, { size = true })
    end

    self:MarkComponentGeometryModified(
        textureData.baselineID, "texCoords", true)
    ApplyIconTexCoords(target)

    local border = self:GetPixelBorder(owner, borderKey)
        or self:CreatePixelBorder(owner, borderKey,
            tonumber(options.borderSize) or tonumber(style.borderSize) or 1,
            nil, options.outside == true, texture)
    if not border then return false end
    border.anchor = texture
    local borderSize = tonumber(options.borderSize)
        or tonumber(style.borderSize) or 1
    self:SetPixelBorderSize(border, math.max(1, borderSize))
    self:SetPixelBorderPadding(border,
        tonumber(options.borderPadding) or tonumber(style.borderPadding) or 0)

    local borderColor = options.borderColor
        or self:GetResolvedAppearanceColor(style, "border")
        or self:GetComponentBorderColor("icon", style)
        or { 1, 1, 1, 1 }
    local borderMode = string.lower(tostring(
        options.borderMode or style.borderMode or "custom"))
    local quality
    if borderMode == "quality" then
        if type(options.qualityProvider) == "function" then
            local ok, provided = pcall(options.qualityProvider, target)
            if ok then quality = provided end
        else
            quality = options.quality
        end
        local item = _G.C_Item
        if quality ~= nil and item and item.GetItemQualityColor then
            local red, green, blue = item.GetItemQualityColor(quality)
            if red then borderColor = { red, green, blue, 1 } end
        end
    end
    self:SetPixelBorderColor(border, unpack(borderColor))
    self:SetPixelBorderShown(border,
        options.showBorder ~= false and borderSize > 0)

    local sizeWatchTarget = target.HookScript and target or owner
    if not data.sizeHooked and sizeWatchTarget and sizeWatchTarget.HookScript then
        sizeWatchTarget:HookScript("OnSizeChanged", function()
            ApplyIconTexCoords(target)
        end)
        data.sizeHooked = true
    end
    if not textureData.sizeHooked and _G.hooksecurefunc then
        local function RefreshTextureCrop()
            ApplyIconTexCoords(target)
        end
        for _, method in ipairs({ "SetSize", "SetWidth", "SetHeight" }) do
            if type(texture[method]) == "function" then
                pcall(_G.hooksecurefunc, texture, method, RefreshTextureCrop)
            end
        end
        textureData.sizeHooked = true
    end
    return true
end

function NSkin:ApplyGlobalTypography(frame)
    if not frame then return end
    local typography = self:GetStyle("typography")
    local font, size, outline = typography.font, typography.size, typography.outline
    if not font and not size and outline == nil then return end

    local function Apply(target)
        if target.GetObjectType and target:GetObjectType() == "FontString" then
            local currentFont, currentSize, currentOutline = target:GetFont()
            target:SetFont(font or currentFont, size or currentSize,
                outline ~= nil and outline or currentOutline)
        elseif target.GetObjectType and target:GetObjectType() == "EditBox"
            and target.SetFont
        then
            local currentFont, currentSize, currentOutline = target:GetFont()
            target:SetFont(font or currentFont, size or currentSize,
                outline ~= nil and outline or currentOutline)
        end
        if target.GetRegions then
            for _, region in ipairs({ target:GetRegions() }) do
                if region.GetObjectType and region:GetObjectType() == "FontString" then
                    local currentFont, currentSize, currentOutline = region:GetFont()
                    region:SetFont(font or currentFont, size or currentSize,
                        outline ~= nil and outline or currentOutline)
                end
            end
        end
        if target.GetChildren then
            for _, child in ipairs({ target:GetChildren() }) do Apply(child) end
        end
    end

    Apply(frame)
end
local function HideProgressBarArtwork(region, fill)
    if region == fill or not region or not region.IsObjectType
        or not region:IsObjectType("Texture")
    then return end
    region:SetAlpha(0)
    region:SetTexture(nil)
    region:Hide()
end

local function CenterProgressBarText(bar, region, offsetX, offsetY)
    if not region or not region.IsObjectType or not region:IsObjectType("FontString") then
        return
    end
    region:ClearAllPoints()
    region:SetPoint("CENTER", bar, "CENTER", offsetX, offsetY)
end

function NSkin:SkinProgressBar(bar, options)
    if not bar or not bar.GetObjectType or bar:GetObjectType() ~= "StatusBar"
        or not bar.SetStatusBarTexture or (bar.IsForbidden and bar:IsForbidden())
    then return false end
    options = options or {}
    local style = self:GetStyle("progressBar")
    local data = self:GetSkinData(bar, PROGRESS_COMPONENT_STATE)
    if not data.baselineID then
        data.baselineID = "ProgressBar:" .. tostring(bar)
        self:CaptureComponentBaseline(data.baselineID, bar, { size = true })
    end
    local baseline = self:GetComponentBaseline(data.baselineID)
    if not data.originalHeight then
        data.originalHeight = baseline and baseline.height or bar:GetHeight()
    end
    local height = tonumber(options.height)
    if height and height > 0 then
        self:MarkComponentGeometryModified(data.baselineID, "size", true)
        bar:SetHeight(height)
    elseif baseline and baseline.modified.size then
        self:RestoreComponentBaseline(data.baselineID, { size = true })
    end

    local fill = bar:GetStatusBarTexture()
    if type(options.artworkRegions) == "table" then
        for i = 1, #options.artworkRegions do
            HideProgressBarArtwork(options.artworkRegions[i], fill)
        end
    elseif options.stripArtwork and not data.artworkStripped and bar.GetRegions then
        local regions = { bar:GetRegions() }
        for i = 1, #regions do HideProgressBarArtwork(regions[i], fill) end
        data.artworkStripped = true
    end

    local texture = options.texture
    if options.useAppearanceTexture then texture = style and style.texture end
    if type(texture) == "string" and texture ~= "" then
        bar:SetStatusBarTexture(texture)
        fill = bar:GetStatusBarTexture()
        if fill then
            fill:Show()
            if fill.SetHorizTile then fill:SetHorizTile(false) end
            if fill.SetVertTile then fill:SetVertTile(false) end
        end
    end

    if options.background then
        local backgroundColor = options.backgroundColor or style.background
        local borderColor = options.borderColor or self:GetWindowBorderColor()
            or style.border
        local background = self:CreateFlatBackground(
            bar, PROGRESS_BACKGROUND_KEY, backgroundColor, borderColor)
        if background then
            -- Blizzard progress templates can alter their regions again while
            -- refreshing. Reassert the complete NSkin-owned surface each pass.
            local pixel = self:GetPhysicalPixelSize(bar)
            background:ClearAllPoints()
            background:SetPoint("TOPLEFT", bar, "TOPLEFT", pixel, -pixel)
            background:SetPoint(
                "BOTTOMRIGHT", bar, "BOTTOMRIGHT", -pixel, pixel)
            background:SetColorTexture(unpack(backgroundColor))
            background:SetAlpha(1)
            background:Show()
        end
        local border = self:GetPixelBorder(
            bar, PROGRESS_BACKGROUND_KEY .. "Border")
        self:SetPixelBorderColor(border, unpack(borderColor))
        self:SetPixelBorderSize(border, 1)
        self:SetPixelBorderPadding(border, 0)
        self:SetPixelBorderShown(border, true)
    end

    if options.centerText then
        local offsetX = tonumber(options.textOffsetX) or 0
        local offsetY = tonumber(options.textOffsetY) or 0
        if type(options.textRegions) == "table" then
            for i = 1, #options.textRegions do
                CenterProgressBarText(bar, options.textRegions[i], offsetX, offsetY)
            end
        else
            CenterProgressBarText(bar, bar.Label, offsetX, offsetY)
            if bar.GetRegions then
                local regions = { bar:GetRegions() }
                for i = 1, #regions do
                    CenterProgressBarText(bar, regions[i], offsetX, offsetY)
                end
            end
        end
    end
    return true
end

function NSkin:RegisterProgressBarElement(definition)
    if type(definition) ~= "table" then return nil end
    definition.kind = definition.kind or "PROGRESS_BAR"
    return self:RegisterSimpleMovableElement(definition)
end
