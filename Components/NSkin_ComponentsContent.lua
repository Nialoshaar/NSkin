local _, NSkin = ...

local COMPONENT_STATE = "components"
local COLUMN_HEADER_STATE = "columnHeaderComponent"
local ROW_STATE = "rowComponent"
local COLUMN_HEADER_BACKGROUND = "NSkinColumnHeaderBackground"
local ROW_BACKGROUND = "NSkinRowBackground"

-- A repeated SECTION_HEADERS family supplies its own active targets and
-- Blizzard decoration fields.  The shared component owns presentation and
-- first-write text placement for every pooled instance.
function NSkin:SkinSectionHeader(target, options)
    if not target or not target.CreateTexture
        or (target.IsForbidden and target:IsForbidden())
    then return false end
    options = options or {}
    local state = self:GetSkinData(target, "sectionHeaderComponent")
    if options.reset then
        if state.textBaselineID then
            self:RestoreComponentBaseline(state.textBaselineID,
                { points = true })
        end
        if state.text then self:SkinText(state.text, nil, { reset = true }) end
        for region, original in pairs(state.decorations or {}) do
            if original.atlas and region.SetAtlas then
                region:SetAtlas(original.atlas, false)
            elseif region.SetTexture then
                region:SetTexture(original.texture)
            end
            if region.SetAlpha then region:SetAlpha(original.alpha) end
            if region.SetShown then region:SetShown(original.shown) end
        end
        if state.underline then state.underline:Hide() end
        return true
    end
    local style = options.style or self:GetStyle("sectionHeader")
    if not style then return false end
    local text = options.text or target.Text
    if text and not (text.IsForbidden and text:IsForbidden()) then
        if state.text ~= text then
            if state.textBaselineID then
                self:RestoreComponentBaseline(state.textBaselineID,
                    { points = true })
            end
            if state.text then
                self:SkinText(state.text, nil, { reset = true })
            end
            state.text = text
            state.textBaselineID = "SectionHeaderText:" .. tostring(text)
            self:CaptureComponentBaseline(state.textBaselineID, text,
                { points = true })
        end
        local baseline = self:GetComponentBaseline(state.textBaselineID)
        local offset = options.offset or {}
        local x = tonumber(offset.offsetX) or 0
        local y = tonumber(offset.offsetY) or 0
        if baseline and baseline.points and text.ClearAllPoints then
            text:ClearAllPoints()
            for _, point in ipairs(baseline.points) do
                text:SetPoint(point[1], point[2], point[3],
                    (point[4] or 0) + x, (point[5] or 0) + y)
            end
            self:MarkComponentGeometryModified(
                state.textBaselineID, "points", x ~= 0 or y ~= 0)
        end
        local textStyle = state.textStyle or {}
        state.textStyle = textStyle
        setmetatable(textStyle, { __index = style })
        textStyle.color = style.text
        textStyle.colorMode = style.textMode
        textStyle.sizeMode = nil
        textStyle.textSize = nil
        local defaultSize = tonumber(options.defaultTextSize)
        if defaultSize and style.sizeMode ~= "CUSTOM" then
            textStyle.sizeMode = "CUSTOM"
            textStyle.textSize = defaultSize
        end
        self:SkinText(text, textStyle)
    end
    state.decorations = state.decorations or {}
    for _, region in ipairs(options.nativeDecorations or {}) do
        if region and not (region.IsForbidden and region:IsForbidden()) then
            if not state.decorations[region] then
                state.decorations[region] = {
                    atlas = region.GetAtlas and region:GetAtlas(),
                    texture = region.GetTexture and region:GetTexture(),
                    alpha = region.GetAlpha and region:GetAlpha() or 1,
                    shown = region.IsShown and region:IsShown() or false,
                }
            end
            if region.SetAlpha then region:SetAlpha(0) end
            if region.Hide then region:Hide() end
        end
    end
    local underline = state.underline
    if not underline then
        underline = target:CreateTexture(nil, "ARTWORK", nil, 1)
        self:ConfigureOwnedPixelTexture(underline)
        state.underline = underline
    end
    local placement = options.underline or {}
    local x = tonumber((options.offset or {}).offsetX) or 0
    local y = tonumber((options.offset or {}).offsetY) or 0
    underline:ClearAllPoints()
    underline:SetPoint("BOTTOMLEFT", target, "BOTTOMLEFT",
        (tonumber(placement.left) or 0) + x,
        (tonumber(placement.y) or 0) + y)
    underline:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT",
        (tonumber(placement.right) or 0) + x,
        (tonumber(placement.y) or 0) + y)
    underline:SetHeight(tonumber(style.underlineSize) or 1)
    self:SetOwnedTextureColor(underline, unpack(
        self:GetResolvedAppearanceColor(style, "underline")))
    underline:SetShown(style.underlineVisible == true)
    return true, underline
end

function NSkin:GetSectionHeaderUnderline(target)
    local state = target and self:GetSkinData(
        target, "sectionHeaderComponent", false)
    return state and state.underline
end

local function ResolveContentValue(value, target)
    if type(value) ~= "function" then return value end
    local ok, resolved = pcall(value, target)
    return ok and resolved or nil
end

local function AnchorContentSurface(region, visualRegion, inset)
    if not region or not visualRegion or not region.ClearAllPoints
        or not region.SetPoint
    then return end
    inset = tonumber(inset) or 0
    region:ClearAllPoints()
    region:SetPoint("TOPLEFT", visualRegion, "TOPLEFT", inset, -inset)
    region:SetPoint("BOTTOMRIGHT", visualRegion, "BOTTOMRIGHT", -inset, inset)
end

local function ResolveContentSurfaceAnchor(
    target, state, visualRegion, width, height)
    if not target or not state or not visualRegion then return visualRegion end
    local anchor = state.surfaceAnchor
    if not anchor then
        anchor = CreateFrame("Frame", nil, target)
        anchor:EnableMouse(false)
        state.surfaceAnchor = anchor
    end
    anchor:ClearAllPoints()
    anchor:SetPoint("TOPLEFT", visualRegion, "TOPLEFT", 0, 0)
    local resolvedWidth = tonumber(width)
    local resolvedHeight = tonumber(height)
    if not resolvedWidth or resolvedWidth <= 0 then
        resolvedWidth = visualRegion.GetWidth and visualRegion:GetWidth() or 1
    end
    if not resolvedHeight or resolvedHeight <= 0 then
        resolvedHeight = visualRegion.GetHeight and visualRegion:GetHeight() or 1
    end
    anchor:SetSize(math.max(1, resolvedWidth), math.max(1, resolvedHeight))
    return anchor
end

local function HideDeclaredContentArtwork(region)
    if not region or not region.GetObjectType then return end
    if region.SetAlpha then region:SetAlpha(0) end
    if region:GetObjectType() == "Texture" and region.SetTexture then
        region:SetTexture(nil)
    end
    if region.Hide then region:Hide() end
end

local function SuppressDeclaredContentArtwork(regions, preserved)
    preserved = preserved or {}
    for _, region in ipairs(regions or {}) do
        if region and not preserved[region] then
            HideDeclaredContentArtwork(region)
        end
    end
end

local function PreserveContentRegions(preserved, regions)
    if regions and regions.GetObjectType then
        preserved[regions] = true
        return
    end
    for _, region in ipairs(regions or {}) do
        if region then preserved[region] = true end
    end
end

local function ResolveContentState(provider, fallback, target)
    if type(provider) == "function" then
        local ok, value = pcall(provider, target)
        if ok then return value == true end
    end
    return fallback and fallback.IsShown and fallback:IsShown() == true
        or false
end

local function RestoreContentStateRegion(state)
    local region = state and state.region
    if not region then return end
    state.active = nil
    state.applying = true
    if state.alpha ~= nil and region.SetAlpha then region:SetAlpha(state.alpha) end
    if state.shown ~= nil and region.SetShown then
        region:SetShown(state.shown)
    end
    state.applying = nil
end

local function ResolveRowRegions(value, target)
    if type(value) == "function" then
        local ok, resolved = pcall(value, target)
        value = ok and resolved or nil
    end
    if not value then return {} end
    if value.GetObjectType then return { value } end
    return type(value) == "table" and value or {}
end

local RefreshRowPresentation
local RefreshRowContentAppearance

local function RestoreRowContentRegion(regionState)
    local region = regionState and regionState.region
    if not region then return end
    regionState.active = nil
    regionState.applying = true
    if regionState.color and region.SetTextColor then
        region:SetTextColor(unpack(regionState.color))
    end
    if regionState.vertexColor and region.SetVertexColor then
        region:SetVertexColor(unpack(regionState.vertexColor))
    end
    if regionState.font and region.SetFont then
        region:SetFont(unpack(regionState.font))
    end
    regionState.applying = nil
end

local function ApplyRowContentRegions(target, state, declared, excluded)
    local active = {}
    for _, region in ipairs(ResolveRowRegions(
        declared, target))
    do
        if region and not (excluded and excluded[region])
            and region.GetFont and region.SetTextColor
        then
            active[region] = true
        end
    end
    state.contentRegionStates = state.contentRegionStates or {}
    for region, regionState in pairs(state.contentRegionStates) do
        if regionState.active and not active[region] then
            RestoreRowContentRegion(regionState)
        end
    end
    for region in pairs(active) do
        local regionState = state.contentRegionStates[region]
        if not regionState then
            regionState = { region = region }
            if region.GetTextColor then
                regionState.color = { region:GetTextColor() }
            end
            if region.GetVertexColor then
                regionState.vertexColor = { region:GetVertexColor() }
            end
            if region.GetFont then regionState.font = { region:GetFont() } end
            state.contentRegionStates[region] = regionState
        end
        regionState.active = true
        if not regionState.hooked and _G.hooksecurefunc then
            local function ReassertContentAppearance()
                if not regionState.applying then
                    RefreshRowContentAppearance(target)
                end
            end
            for _, method in ipairs({ "SetTextColor", "SetVertexColor" }) do
                if type(region[method]) == "function" then
                    pcall(_G.hooksecurefunc, region, method,
                        ReassertContentAppearance)
                end
            end
            regionState.hooked = true
        end
    end
end

local ROW_COLUMN_KINDS = {
    TEXT = true,
    ICON = true,
    BUTTON = true,
    ACTION_BUTTON = true,
    CHECKBOX = true,
}

local function CaptureRowButtonRegions(button)
    local regions = {}
    if not button.GetRegions then return regions end
    for _, region in ipairs({ button:GetRegions() }) do
        local forbidden = region.IsForbidden and region:IsForbidden()
        local kind = not forbidden and region.GetObjectType
            and region:GetObjectType()
        if kind == "Texture" then
            regions[#regions + 1] = {
                region = region,
                kind = kind,
                alpha = region.GetAlpha and region:GetAlpha(),
                shown = region.IsShown and region:IsShown(),
                atlas = region.GetAtlas and region:GetAtlas(),
                texture = region.GetTexture and region:GetTexture(),
            }
        elseif kind == "FontString" then
            regions[#regions + 1] = {
                region = region,
                kind = kind,
                alpha = region.GetAlpha and region:GetAlpha(),
                shown = region.IsShown and region:IsShown(),
                color = region.GetTextColor and { region:GetTextColor() },
                font = region.GetFont and { region:GetFont() },
                text = region.GetText and region:GetText(),
            }
        end
    end
    return regions
end

local function RestoreRowButtonColumn(columnState)
    local button = columnState.target
    local data = NSkin:GetSkinData(button, COMPONENT_STATE, false)
    if columnState.kind == "CHECKBOX" then
        if data then
            data.checkButtonActive = nil
            data.checkButtonGetChecked = nil
        end
        if columnState.checkboxLabel then
            NSkin:SkinText(columnState.checkboxLabel, nil, { reset = true })
        end
        if button.SetCheckedTexture then
            button:SetCheckedTexture(columnState.checkedTexture)
        end
        if data and data.checkButtonCheckedTexture then
            data.checkButtonCheckedTexture:Hide()
        end
    end
    if data then
        data.actionActive = nil
        data.hoverGlowManaged = true
        if data.hoverGlow then data.hoverGlow:Hide() end
        if data.label and not columnState.originalRegions[data.label] then
            data.label:Hide()
            data.rowColumnLabel = data.label
        end
        if data.actionOwnedLabel then data.actionOwnedLabel:Hide() end
        data.label = nil
    end
    local background = NSkin:GetFlatBackground(button)
    if background then background:Hide() end
    NSkin:SetPixelBorderShown(NSkin:GetPixelBorder(button,
        "NSkinFlatBackgroundBorder"), false)
    for _, original in ipairs(columnState.buttonRegions or {}) do
        local region = original.region
        if original.kind == "Texture" then
            if original.atlas and region.SetAtlas then
                region:SetAtlas(original.atlas)
            elseif region.SetTexture then
                region:SetTexture(original.texture)
            end
        elseif original.kind == "FontString" then
            if original.text ~= nil and region.SetText then
                region:SetText(original.text)
            end
            if original.font and region.SetFont then
                region:SetFont(unpack(original.font))
            end
            if original.color and region.SetTextColor then
                region:SetTextColor(unpack(original.color))
            end
        end
        if original.alpha ~= nil and region.SetAlpha then
            region:SetAlpha(original.alpha)
        end
        if original.shown ~= nil and region.SetShown then
            region:SetShown(original.shown)
        end
    end
end

local function ResetRowColumn(columnState)
    local target = columnState.target
    if columnState.kind == "TEXT" then
        NSkin:SkinText(target, nil, { reset = true })
    elseif columnState.kind == "ICON" then
        NSkin:SkinIcon(columnState.iconTarget or target, {
            texture = columnState.texture,
            borderOwner = columnState.borderOwner,
            borderKey = columnState.borderKey,
            reset = true,
        })
    else
        RestoreRowButtonColumn(columnState)
    end
end

local function ResolveRowColumns(target, declared)
    local resolved = ResolveContentValue(declared, target)
    local columns, targets = {}, {}
    for _, column in ipairs(type(resolved) == "table" and resolved or {}) do
        if type(column) == "table" and ROW_COLUMN_KINDS[column.kind] then
            local child = ResolveContentValue(column.target, target)
            if child and child.GetObjectType
                and not (child.IsForbidden and child:IsForbidden())
                and not targets[child]
            then
                local entry = {}
                for key, value in pairs(column) do entry[key] = value end
                entry.target = child
                if type(entry.text) == "function" then
                    entry.text = ResolveContentValue(entry.text, target)
                end
                if entry.texture then
                    entry.texture = ResolveContentValue(entry.texture, target)
                end
                if not (entry.texture and entry.texture.IsForbidden
                    and entry.texture:IsForbidden())
                then
                    columns[#columns + 1] = entry
                    targets[child] = true
                end
            end
        end
    end
    return columns, targets
end

local function ReconcileRowColumns(state, columns)
    local current = {}
    for _, column in ipairs(columns) do current[column.target] = column end
    state.columnStates = state.columnStates or {}
    for target, previous in pairs(state.columnStates) do
        local column = current[target]
        if not column or column.kind ~= previous.kind
            or (column.kind == "ICON"
                and (column.texture ~= previous.declaredTexture
                    or column.iconTarget ~= previous.declaredIconTarget))
        then
            ResetRowColumn(previous)
            state.columnStates[target] = nil
        end
    end
end

local function ApplyRowColumns(target, state, columns, options)
    state.buttonBaselines = state.buttonBaselines
        or setmetatable({}, { __mode = "k" })
    for _, column in ipairs(columns) do
        local child = column.target
        local columnState = state.columnStates[child]
        if not columnState then
            columnState = {
                kind = column.kind,
                target = child,
                declaredTexture = column.texture,
                declaredIconTarget = column.iconTarget,
                iconTarget = column.iconTarget or child,
                texture = column.texture,
                borderOwner = column.borderOwner,
                borderKey = column.borderKey,
            }
            if column.kind == "BUTTON" or column.kind == "ACTION_BUTTON"
                or column.kind == "CHECKBOX"
            then
                local baseline = state.buttonBaselines[child]
                if not baseline then
                    baseline = {
                        regions = CaptureRowButtonRegions(child),
                        originalRegions = {},
                    }
                    for _, original in ipairs(baseline.regions) do
                        baseline.originalRegions[original.region] = true
                    end
                    state.buttonBaselines[child] = baseline
                end
                columnState.buttonRegions = baseline.regions
                columnState.originalRegions = baseline.originalRegions
                if column.kind == "CHECKBOX" then
                    columnState.checkedTexture = child.GetCheckedTexture
                        and child:GetCheckedTexture()
                    columnState.checkboxLabel = column.text or child.Text
                        or child.text
                end
            end
            state.columnStates[child] = columnState
        end
        local definition = {}
        for key, value in pairs(column) do definition[key] = value end
        definition.id = column.appearanceID or options.elementID
        definition.appearanceWindowID = options.appearanceWindowID
        definition.skinOptions = column.skinOptions
        if column.kind == "BUTTON" then
            local buttonData = NSkin:GetSkinData(child, COMPONENT_STATE, false)
            if buttonData and buttonData.rowColumnLabel then
                buttonData.label = buttonData.rowColumnLabel
            end
        end
        if columnState.buttonRegions and NSkin:GetFlatBackground(child) then
            local preserved = column.preserveTexture
                or (column.skinOptions and column.skinOptions.preserveTexture)
            for _, original in ipairs(columnState.buttonRegions) do
                local region = original.region
                if original.kind == "Texture" and region ~= preserved then
                    region:SetAlpha(0)
                    region:SetTexture(nil)
                    region:Hide()
                end
            end
        end
        NSkin:SkinTypedElement(column.kind, definition)
        if column.kind == "ICON" then
            local iconState = NSkin:GetSkinData(
                columnState.iconTarget, "iconComponent", false)
            if iconState then
                columnState.texture = iconState.texture or column.texture
                columnState.borderOwner = iconState.borderOwner
                columnState.borderKey = iconState.borderKey
            end
        end
    end
end

RefreshRowContentAppearance = function(target)
    local state = NSkin:GetSkinData(target, ROW_STATE, false)
    if not state or not state.active or state.applyingContent
        or not state.contentStyle
    then return end
    state.applyingContent = true
    for _, regionState in pairs(state.contentRegionStates or {}) do
        if regionState.active then
            regionState.applying = true
            NSkin:SkinText(regionState.region, state.contentStyle,
                state.contentTextOptions)
            regionState.applying = nil
        end
    end
    state.applyingContent = nil
end

local function ConcealRowStateRegion(rowState, regionState)
    local region = regionState and regionState.region
    if not rowState.active or not regionState.active
        or regionState.applying or not region
    then return end
    regionState.applying = true
    if region.SetAlpha then region:SetAlpha(0)
    elseif region.Hide then region:Hide() end
    regionState.applying = nil
end

local function ApplyRowNativeDecorations(target, state, declared, preserved)
    local active = {}
    for _, region in ipairs(ResolveRowRegions(
        declared, target))
    do
        if region and not preserved[region] then active[region] = true end
    end
    state.nativeDecorationStates = state.nativeDecorationStates or {}
    for region, regionState in pairs(state.nativeDecorationStates) do
        if regionState.active and not active[region] then
            RestoreContentStateRegion(regionState)
        end
    end
    for region in pairs(active) do
        local regionState = state.nativeDecorationStates[region]
        if not regionState then
            regionState = {
                region = region,
                alpha = region.GetAlpha and region:GetAlpha() or 1,
                shown = region.IsShown and region:IsShown() or nil,
            }
            state.nativeDecorationStates[region] = regionState
        end
        regionState.active = true
        ConcealRowStateRegion(state, regionState)
        if not regionState.hooked and _G.hooksecurefunc then
            local function MaintainNativeDecoration()
                ConcealRowStateRegion(state, regionState)
            end
            for _, method in ipairs({ "SetAlpha", "SetShown", "Show" }) do
                if type(region[method]) == "function" then
                    pcall(_G.hooksecurefunc, region, method,
                        MaintainNativeDecoration)
                end
            end
            regionState.hooked = true
        end
    end
end

local function ApplyRowStateRegions(target, state, declared)
    local active = {}
    for _, region in ipairs(declared) do
        if region then active[region] = true end
    end
    state.regionStates = state.regionStates or {}
    for region, regionState in pairs(state.regionStates) do
        if regionState.active and not active[region] then
            RestoreContentStateRegion(regionState)
        end
    end
    for region in pairs(active) do
        local regionState = state.regionStates[region]
        if not regionState then
            regionState = {
                region = region,
                alpha = region.GetAlpha and region:GetAlpha() or 1,
                shown = region.IsShown and region:IsShown() or nil,
            }
            state.regionStates[region] = regionState
        end
        regionState.active = true
        ConcealRowStateRegion(state, regionState)
        if not regionState.hooked and _G.hooksecurefunc then
            local function MaintainStateRegion()
                ConcealRowStateRegion(state, regionState)
                RefreshRowPresentation(target)
            end
            for _, method in ipairs({ "SetAlpha", "SetShown", "Show", "Hide" }) do
                if type(region[method]) == "function" then
                    pcall(_G.hooksecurefunc, region, method,
                        MaintainStateRegion)
                end
            end
            regionState.hooked = true
        end
    end
end

RefreshRowPresentation = function(target)
    local state = NSkin:GetSkinData(target, ROW_STATE, false)
    if not state or not state.active then return end
    local selected = ResolveContentState(
        state.getSelected, state.selectedRegion, target)
    local hovered
    if type(state.getHovered) == "function" then
        hovered = ResolveContentState(
            state.getHovered, state.hoverRegion, target)
    else
        hovered = state.pointerHovered == true
    end
    if state.selectedOverlay then state.selectedOverlay:SetShown(selected) end
    if state.hoverOverlay then
        state.hoverOverlay:SetShown(state.showHighlight ~= false and hovered)
    end
    RefreshRowContentAppearance(target)
end

function NSkin:SkinRow(target, options)
    if not target or not target.CreateTexture
        or (target.IsForbidden and target:IsForbidden())
    then return nil end
    options = options or {}
    local state = self:GetSkinData(target, ROW_STATE)
    if options.reset == true then
        state.active = nil
        for target, columnState in pairs(state.columnStates or {}) do
            ResetRowColumn(columnState)
            state.columnStates[target] = nil
        end
        if state.widthModified and state.originalWidth and target.SetWidth then
            target:SetWidth(state.originalWidth)
            state.widthModified = nil
        end
        if state.heightModified and state.originalHeight and target.SetHeight then
            target:SetHeight(state.originalHeight)
            state.heightModified = nil
        end
        for _, regionState in pairs(state.nativeDecorationStates or {}) do
            if regionState.active then RestoreContentStateRegion(regionState) end
        end
        for _, regionState in pairs(state.regionStates or {}) do
            if regionState.active then RestoreContentStateRegion(regionState) end
        end
        for _, regionState in pairs(state.contentRegionStates or {}) do
            if regionState.active then RestoreRowContentRegion(regionState) end
        end
        if state.background then state.background:Hide() end
        if state.border then self:SetPixelBorderShown(state.border, false) end
        if state.selectedOverlay then state.selectedOverlay:Hide() end
        if state.hoverOverlay then state.hoverOverlay:Hide() end
        return state
    end
    local style = options.style or self:GetStyle("row")
    if not style then return nil end
    state.active = true
    state.hoverRegion = ResolveContentValue(options.hoverRegion, target)
        or (target.GetHighlightTexture and target:GetHighlightTexture())
    state.selectedRegion = ResolveContentValue(options.selectedRegion, target)
    state.getHovered = options.getHovered
    state.getSelected = options.getSelected
    if state.pointerHovered == nil then state.pointerHovered = false end
    state.showHighlight = options.showHighlight
    if state.showHighlight == nil then
        state.showHighlight = style.showHighlight ~= false
    end
    state.contentStyle = options.contentStyle
    state.contentTextOptions = options.contentTextOptions
    local visualRegion = ResolveContentValue(options.visualRegion, target)
    if not (visualRegion and visualRegion.GetObjectType) then
        visualRegion = target
    end

    local surfaceWidth = tonumber(options.width) or tonumber(style.width)
    local surfaceHeight = tonumber(options.height) or tonumber(style.height)
    local surfaceRegion = ResolveContentSurfaceAnchor(
        target, state, visualRegion, surfaceWidth, surfaceHeight)

    local backgroundColor = self:GetResolvedAppearanceColor(
        style, "background")
    backgroundColor[4] = tonumber(style.backgroundOpacity)
        or backgroundColor[4] or 1
    local borderColor = options.border
        or (style.borderMode and self:GetResolvedAppearanceColor(style, "border"))
        or self:GetComponentBorderColor("row", style)
    local surfaceInset = tonumber(options.surfaceInset)
    if surfaceInset == nil then surfaceInset = 1 end
    local showBackground = options.showBackground
    if showBackground == nil then showBackground = style.showBackground ~= false end
    local showBorder = options.showBorder
    if showBorder == nil then showBorder = style.showBorder ~= false end
    local background = self:GetFlatBackground(target, ROW_BACKGROUND)
    if showBackground then
        background = self:CreateFlatBackground(
            target, ROW_BACKGROUND, backgroundColor, borderColor)
        -- Table templates commonly place their cell FontStrings on BACKGROUND.
        -- Keep the owned surface below those Blizzard-owned contents.
        if background and background.SetDrawLayer then
            background:SetDrawLayer("BACKGROUND", -8)
        end
        AnchorContentSurface(background, surfaceRegion, surfaceInset)
        if background then background:Show() end
    elseif background then
        background:Hide()
    end
    local border = self:GetPixelBorder(target, ROW_BACKGROUND .. "Border")
        or self:CreatePixelBorder(target, ROW_BACKGROUND .. "Border",
            style.borderSize or 1, borderColor, false, visualRegion)
    state.background = background
    state.border = border
    if border then border.anchor = surfaceRegion end
    self:SetPixelBorderColor(border, unpack(borderColor))
    self:SetPixelBorderSize(border, style.borderSize or 1)
    self:SetPixelBorderPadding(border,
        (tonumber(style.borderPadding) or 0) - surfaceInset)
    self:SetPixelBorderShown(border,
        showBorder and (tonumber(style.borderSize) or 0) > 0)

    if not state.selectedOverlay then
        state.selectedOverlay = target:CreateTexture(nil, "ARTWORK", nil, 6)
        self:ConfigureOwnedPixelTexture(state.selectedOverlay)
    end
    if not state.hoverOverlay then
        state.hoverOverlay = target:CreateTexture(nil, "OVERLAY", nil, -1)
        self:ConfigureOwnedPixelTexture(state.hoverOverlay)
    end
    AnchorContentSurface(state.selectedOverlay, surfaceRegion, surfaceInset)
    AnchorContentSurface(state.hoverOverlay, surfaceRegion, surfaceInset)
    local selectedColor =
        self:GetResolvedAppearanceColor(style, "selectedBackground")
    self:SetOwnedTextureColor(
        state.selectedOverlay,
        selectedColor[1], selectedColor[2], selectedColor[3],
        tonumber(style.selectedBackgroundOpacity)
            or selectedColor[4] or 0.10)
    local highlightColor =
        self:GetResolvedAppearanceColor(style, "highlight")
    self:SetOwnedTextureColor(
        state.hoverOverlay,
        highlightColor[1], highlightColor[2], highlightColor[3],
        tonumber(style.hoverAlpha) or highlightColor[4] or 0.10)

    local preserved = {
        [state.selectedOverlay] = true,
        [state.hoverOverlay] = true,
    }
    if background then preserved[background] = true end
    PreserveContentRegions(preserved, options.preserveTextures)
    ApplyRowNativeDecorations(target, state,
        options.nativeDecorationRegions or options.artworkRegions, preserved)
    ApplyRowStateRegions(target, state, {
        state.hoverRegion, state.selectedRegion,
    })
    local columns, columnTargets = ResolveRowColumns(target, options.columns)
    ReconcileRowColumns(state, columns)
    ApplyRowContentRegions(target, state, options.contentRegions,
        columnTargets)
    ApplyRowColumns(target, state, columns, options)
    if not state.hooked and target.HookScript then
        target:HookScript("OnEnter", function(row)
            local rowState = NSkin:GetSkinData(row, ROW_STATE, false)
            if rowState then rowState.pointerHovered = true end
            RefreshRowPresentation(row)
        end)
        target:HookScript("OnLeave", function(row)
            local rowState = NSkin:GetSkinData(row, ROW_STATE, false)
            if rowState then rowState.pointerHovered = false end
            RefreshRowPresentation(row)
        end)
        target:HookScript("OnShow", function(row)
            local rowState = NSkin:GetSkinData(row, ROW_STATE, false)
            if rowState then rowState.pointerHovered = false end
            RefreshRowPresentation(row)
        end)
        state.hooked = true
    end
    if not state.methodHooksInstalled and _G.hooksecurefunc then
        for _, method in ipairs({
            "LockHighlight", "UnlockHighlight", "SetSelected",
            "SetHighlighted",
        }) do
            if type(target[method]) == "function" then
                pcall(_G.hooksecurefunc, target, method, function()
                    RefreshRowPresentation(target)
                end)
            end
        end
        state.methodHooksInstalled = true
    end
    RefreshRowPresentation(target)
    return state
end

local SECTION_ROW_STATE = "sectionRowComponent"
local SECTION_ROW_BACKGROUND = "NSkinSectionRowBackground"
local RefreshSectionRowPresentation

local function RestoreSectionRowContentRegion(regionState)
    local region = regionState and regionState.region
    if not region then return end
    regionState.active = nil
    regionState.applying = true
    if regionState.color and region.SetTextColor then
        region:SetTextColor(unpack(regionState.color))
    end
    if regionState.vertexColor and region.SetVertexColor then
        region:SetVertexColor(unpack(regionState.vertexColor))
    end
    if regionState.font and region.SetFont then
        region:SetFont(unpack(regionState.font))
    end
    regionState.applying = nil
end

local function RefreshSectionRowContentAppearance(target)
    local state = NSkin:GetSkinData(target, SECTION_ROW_STATE, false)
    if not state or not state.active or state.applyingContent
        or not state.contentStyle
    then return end
    state.applyingContent = true
    for _, regionState in pairs(state.contentRegionStates or {}) do
        if regionState.active then
            regionState.applying = true
            NSkin:SkinText(regionState.region, state.contentStyle,
                state.contentTextOptions)
            regionState.applying = nil
        end
    end
    state.applyingContent = nil
end

local function ApplySectionRowContentRegions(target, state, declared)
    local active = {}
    for _, region in ipairs(ResolveRowRegions(declared, target)) do
        if region and region.GetFont and region.SetTextColor then
            active[region] = true
        end
    end
    state.contentRegionStates = state.contentRegionStates or {}
    for region, regionState in pairs(state.contentRegionStates) do
        if regionState.active and not active[region] then
            RestoreSectionRowContentRegion(regionState)
        end
    end
    for region in pairs(active) do
        local regionState = state.contentRegionStates[region]
        if not regionState then
            regionState = { region = region }
            if region.GetTextColor then
                regionState.color = { region:GetTextColor() }
            end
            if region.GetVertexColor then
                regionState.vertexColor = { region:GetVertexColor() }
            end
            if region.GetFont then regionState.font = { region:GetFont() } end
            state.contentRegionStates[region] = regionState
        end
        regionState.active = true
    end
    RefreshSectionRowContentAppearance(target)
end

local function ApplySectionRowStateRegions(target, state, declared)
    local active = {}
    for _, region in ipairs(declared) do
        if region then active[region] = true end
    end
    state.regionStates = state.regionStates or {}
    for region, regionState in pairs(state.regionStates) do
        if regionState.active and not active[region] then
            RestoreContentStateRegion(regionState)
        end
    end
    for region in pairs(active) do
        local regionState = state.regionStates[region]
        if not regionState then
            regionState = {
                region = region,
                alpha = region.GetAlpha and region:GetAlpha() or 1,
                shown = region.IsShown and region:IsShown() or nil,
            }
            state.regionStates[region] = regionState
        end
        regionState.active = true
        ConcealRowStateRegion(state, regionState)
        if not regionState.hooked and _G.hooksecurefunc then
            local function MaintainStateRegion()
                ConcealRowStateRegion(state, regionState)
                RefreshSectionRowPresentation(target)
            end
            for _, method in ipairs({ "SetAlpha", "SetShown", "Show", "Hide" }) do
                if type(region[method]) == "function" then
                    pcall(_G.hooksecurefunc, region, method, MaintainStateRegion)
                end
            end
            regionState.hooked = true
        end
    end
end

local function RefreshSectionRowCollapseGlow(state)
    local button = state and state.collapseButton
    local glow = state and state.collapseGlow
    if not glow then return end
    local hovered = state.active and button
        and state.collapseHovered == true or false
    glow:SetShown(hovered)
end

local function ApplySectionRowCollapseButton(target, state, button, hoverAlpha)
    if state.collapseButton ~= button and state.collapseGlow then
        state.collapseGlow:Hide()
    end
    state.collapseButton = button
    state.collapseHovered = false
    if not button or not button.CreateTexture then
        state.collapseGlow = nil
        return
    end
    state.collapseGlow = NSkin:CreateFlatButtonGlow(button, hoverAlpha, true)
    if not state.collapseHooks or state.collapseHooks.button ~= button then
        if button.HookScript then
            button:HookScript("OnEnter", function()
                state.collapseHovered = true
                RefreshSectionRowCollapseGlow(state)
            end)
            button:HookScript("OnLeave", function()
                state.collapseHovered = false
                RefreshSectionRowCollapseGlow(state)
            end)
            button:HookScript("OnShow", function()
                state.collapseHovered = false
                RefreshSectionRowCollapseGlow(state)
            end)
        end
        state.collapseHooks = { button = button }
    end
    RefreshSectionRowCollapseGlow(state)
end

RefreshSectionRowPresentation = function(target)
    local state = NSkin:GetSkinData(target, SECTION_ROW_STATE, false)
    if not state or not state.active then return end
    local selected = ResolveContentState(
        state.getSelected, state.selectedRegion, target)
    local hovered
    if type(state.getHovered) == "function" then
        hovered = ResolveContentState(
            state.getHovered, state.hoverRegion, target)
    else
        hovered = state.pointerHovered == true
    end
    if state.selectedOverlay then state.selectedOverlay:SetShown(selected) end
    if state.hoverOverlay then
        state.hoverOverlay:SetShown(state.showHighlight ~= false and hovered)
    end
    RefreshSectionRowContentAppearance(target)
    RefreshSectionRowCollapseGlow(state)
end

function NSkin:SkinSectionRow(target, options)
    if not target or not target.CreateTexture
        or (target.IsForbidden and target:IsForbidden())
    then return nil end
    options = options or {}
    local state = self:GetSkinData(target, SECTION_ROW_STATE)
    if options.reset == true then
        state.active = nil
        for _, regionState in pairs(state.nativeDecorationStates or {}) do
            if regionState.active then RestoreContentStateRegion(regionState) end
        end
        for _, regionState in pairs(state.regionStates or {}) do
            if regionState.active then RestoreContentStateRegion(regionState) end
        end
        for _, regionState in pairs(state.contentRegionStates or {}) do
            if regionState.active then RestoreSectionRowContentRegion(regionState) end
        end
        if state.widthModified and state.originalWidth and target.SetWidth then
            target:SetWidth(state.originalWidth)
            state.widthModified = nil
        end
        if state.heightModified and state.originalHeight and target.SetHeight then
            target:SetHeight(state.originalHeight)
            state.heightModified = nil
        end
        if state.background then state.background:Hide() end
        if state.border then self:SetPixelBorderShown(state.border, false) end
        if state.selectedOverlay then state.selectedOverlay:Hide() end
        if state.hoverOverlay then state.hoverOverlay:Hide() end
        if state.collapseGlow then state.collapseGlow:Hide() end
        return state
    end

    local style = options.style or self:GetStyle("sectionRow")
    if not style then return nil end
    state.active = true
    state.hoverRegion = ResolveContentValue(options.hoverRegion, target)
        or (target.GetHighlightTexture and target:GetHighlightTexture())
    state.selectedRegion = ResolveContentValue(options.selectedRegion, target)
    state.getHovered = options.getHovered
    state.getSelected = options.getSelected
    if state.pointerHovered == nil then state.pointerHovered = false end
    state.showHighlight = options.showHighlight
    if state.showHighlight == nil then
        state.showHighlight = style.showHighlight ~= false
    end
    state.hoverEventsManaged = type(options.getHovered) == "function"
    state.pointerHovered = false
    state.contentStyle = options.contentStyle
    state.contentTextOptions = options.contentTextOptions
    local visualRegion = ResolveContentValue(options.visualRegion, target)
    if not (visualRegion and visualRegion.GetObjectType) then
        visualRegion = target
    end

    local surfaceWidth = tonumber(options.width) or tonumber(style.width)
    local surfaceHeight = tonumber(options.height) or tonumber(style.height)
    local surfaceRegion = ResolveContentSurfaceAnchor(
        target, state, visualRegion, surfaceWidth, surfaceHeight)

    local backgroundColor = self:GetResolvedAppearanceColor(style, "background")
    backgroundColor[4] = tonumber(style.backgroundOpacity)
        or backgroundColor[4] or 1
    local borderColor = options.border
        or (style.borderMode and self:GetResolvedAppearanceColor(style, "border"))
        or self:GetComponentBorderColor("sectionRow", style)
    local showBackground = options.showBackground
    if showBackground == nil then showBackground = style.showBackground ~= false end
    local showBorder = options.showBorder
    if showBorder == nil then showBorder = style.showBorder == true end
    local surfaceInset = 1
    local background = self:GetFlatBackground(target, SECTION_ROW_BACKGROUND)
    if showBackground then
        background = self:CreateFlatBackground(
            target, SECTION_ROW_BACKGROUND, backgroundColor, borderColor)
        if background and background.SetDrawLayer then
            background:SetDrawLayer("BACKGROUND", -8)
        end
        AnchorContentSurface(background, surfaceRegion, surfaceInset)
        if background then background:Show() end
    elseif background then
        background:Hide()
    end
    local border = self:GetPixelBorder(
        target, SECTION_ROW_BACKGROUND .. "Border")
        or self:CreatePixelBorder(
            target, SECTION_ROW_BACKGROUND .. "Border",
            style.borderSize or 1, borderColor, false, visualRegion)
    state.background = background
    state.border = border
    if border then border.anchor = surfaceRegion end
    self:SetPixelBorderColor(border, unpack(borderColor))
    self:SetPixelBorderSize(border, style.borderSize or 1)
    self:SetPixelBorderPadding(border,
        (tonumber(style.borderPadding) or 0) - surfaceInset)
    self:SetPixelBorderShown(border,
        showBorder and (tonumber(style.borderSize) or 0) > 0)

    if not state.selectedOverlay then
        state.selectedOverlay = target:CreateTexture(nil, "ARTWORK", nil, 6)
        self:ConfigureOwnedPixelTexture(state.selectedOverlay)
    end
    if not state.hoverOverlay then
        state.hoverOverlay = target:CreateTexture(nil, "OVERLAY", nil, -1)
        self:ConfigureOwnedPixelTexture(state.hoverOverlay)
    end
    AnchorContentSurface(state.selectedOverlay, surfaceRegion, 1)
    AnchorContentSurface(state.hoverOverlay, surfaceRegion, 1)
    local selectedColor =
        self:GetResolvedAppearanceColor(style, "selectedBackground")
    self:SetOwnedTextureColor(
        state.selectedOverlay,
        selectedColor[1], selectedColor[2], selectedColor[3],
        tonumber(style.selectedBackgroundOpacity)
            or selectedColor[4] or 0.10)
    local highlightColor =
        self:GetResolvedAppearanceColor(style, "highlight")
    self:SetOwnedTextureColor(
        state.hoverOverlay,
        highlightColor[1], highlightColor[2], highlightColor[3],
        tonumber(style.hoverAlpha) or highlightColor[4] or 0.10)

    local preserved = {
        [state.selectedOverlay] = true,
        [state.hoverOverlay] = true,
    }
    if background then preserved[background] = true end
    PreserveContentRegions(preserved, options.preserveTextures)
    ApplyRowNativeDecorations(target, state,
        options.nativeDecorationRegions or options.artworkRegions, preserved)
    local stateRegions = {}
    if state.hoverRegion then stateRegions[#stateRegions + 1] = state.hoverRegion end
    if state.selectedRegion then
        stateRegions[#stateRegions + 1] = state.selectedRegion
    end
    ApplySectionRowStateRegions(target, state, stateRegions)
    local contentRegions = options.contentRegions or options.textRegion
        or target.Label or target.Text
        or (target.GetFontString and target:GetFontString())
    ApplySectionRowContentRegions(target, state, contentRegions)
    ApplySectionRowCollapseButton(target, state,
        ResolveContentValue(options.collapseButton, target), style.hoverAlpha)

    if not state.hooked and target.HookScript then
        target:HookScript("OnEnter", function(row)
            local rowState = NSkin:GetSkinData(
                row, SECTION_ROW_STATE, false)
            if rowState then rowState.pointerHovered = true end
            RefreshSectionRowPresentation(row)
        end)
        target:HookScript("OnLeave", function(row)
            local rowState = NSkin:GetSkinData(
                row, SECTION_ROW_STATE, false)
            if rowState then rowState.pointerHovered = false end
            RefreshSectionRowPresentation(row)
        end)
        target:HookScript("OnShow", function(row)
            local rowState = NSkin:GetSkinData(
                row, SECTION_ROW_STATE, false)
            if rowState then rowState.pointerHovered = false end
            RefreshSectionRowPresentation(row)
        end)
        state.hooked = true
    end
    if not state.methodHooksInstalled and _G.hooksecurefunc then
        for _, method in ipairs({
            "LockHighlight", "UnlockHighlight", "SetSelected",
        }) do
            if type(target[method]) == "function" then
                pcall(_G.hooksecurefunc, target, method, function()
                    RefreshSectionRowPresentation(target)
                end)
            end
        end
        state.methodHooksInstalled = true
    end
    RefreshSectionRowPresentation(target)
    return state
end


-- Part 4A: ROW and SECTION_ROW are presentation families only. They no longer
-- participate in the canonical component registry or editor identity. A
-- logical row family is exposed as a REGULAR COMPOSITE whose members are
-- canonical atomic component kinds. Runtime/pooled frames are resolved from
-- the existing audited row presentation state.
local ROW_FAMILY_OPTION_KIND = {
    ["shared.textAppearance"] = "TEXT",
    ["shared.iconAppearance"] = "ICON",
    ["shared.checkboxAppearance"] = "CHECKBOX",
    ["shared.progressBarAppearance"] = "PROGRESS_BAR",
    ["shared.buttonAppearance"] = "BUTTON",
}

local function ResolveRowFamilyTargets(element)
    if not element then return {} end
    local provider = element.rowFamilyTargets or element.highlightRegions
    local targets
    if type(provider) == "function" then
        local ok, resolved = pcall(provider, element)
        targets = ok and resolved or nil
    elseif type(provider) == "table" then
        targets = provider
    end
    if type(targets) ~= "table" then return {} end
    local result = {}
    for i = 1, #targets do
        local target = targets[i]
        if target and (not target.IsForbidden or not target:IsForbidden()) then
            result[#result + 1] = target
        end
    end
    return result
end

local function AppendUniqueRowFamilyTarget(result, seen, target)
    if target and not seen[target]
        and (not target.IsForbidden or not target:IsForbidden())
    then
        seen[target] = true
        result[#result + 1] = target
    end
end

local function AppendCustomRowFamilyTargets(element, kind, result, seen)
    local providers = element and element.rowFamilyMemberTargets
    local provider = providers and providers[kind]
    local targets
    if type(provider) == "function" then
        local ok, resolved = pcall(provider, element, kind)
        targets = ok and resolved or nil
    elseif type(provider) == "table" then
        targets = provider
    end
    for i = 1, #(targets or {}) do
        AppendUniqueRowFamilyTarget(result, seen, targets[i])
    end
end

function NSkin:GetRowFamilyMemberTargets(element, member)
    if not element or not member then return {} end
    if member.rowFamilySurface == true then
        return ResolveRowFamilyTargets(element)
    end

    local result, seen = {}, {}
    AppendCustomRowFamilyTargets(element, member.kind, result, seen)
    local stateKey = element.rowFamily == "sectionRow"
        and SECTION_ROW_STATE or ROW_STATE

    for _, row in ipairs(ResolveRowFamilyTargets(element)) do
        local state = self:GetSkinData(row, stateKey, false)
        if state then
            if member.kind == "TEXT" then
                for _, regionState in pairs(state.contentRegionStates or {}) do
                    if regionState.active then
                        AppendUniqueRowFamilyTarget(
                            result, seen, regionState.region)
                    end
                end
            end
            for _, columnState in pairs(state.columnStates or {}) do
                if columnState.kind == member.kind then
                    local target = member.kind == "ICON"
                        and (columnState.iconTarget or columnState.target)
                        or columnState.target
                    AppendUniqueRowFamilyTarget(result, seen, target)
                end
                if member.kind == "TEXT" and columnState.checkboxLabel then
                    AppendUniqueRowFamilyTarget(
                        result, seen, columnState.checkboxLabel)
                end
            end
            if member.kind == "BUTTON" and state.collapseButton then
                AppendUniqueRowFamilyTarget(
                    result, seen, state.collapseButton)
            end
        end
    end
    return result
end

local function CopyRowFamilyEditorOption(option)
    local copy = {}
    for key, value in pairs(option or {}) do copy[key] = value end
    return copy
end

local function GetRowFamilySurfaceOptions()
    return {
        {
            id = "shared.surfaceGeometry",
            label = "Surface",
            category = "CUSTOMIZE",
            contextualInline = true,
        },
        {
            id = "shared.surfaceBackground",
            label = "Background",
            category = "CUSTOMIZE",
            contextualInline = false,
            headerToggleKey = "showBackground",
        },
        {
            id = "shared.surfaceBorder",
            label = "Border",
            category = "CUSTOMIZE",
            contextualInline = false,
            headerToggleKey = "showBorder",
        },
        {
            id = "shared.surfaceHighlight",
            label = "Highlight",
            category = "CUSTOMIZE",
            contextualInline = false,
            headerToggleKey = "showHighlight",
        },
    }
end

local function CollectRowFamilyKinds(definition)
    local result, seen = {}, {}
    local function Add(kind)
        if type(kind) ~= "string" or kind == ""
            or kind == "ROW" or kind == "SECTION_ROW"
        then return end
        kind = NSkin:GetCanonicalSharedElementType(kind)
        if seen[kind] then return end
        if NSkin:GetSharedElementType(kind) then
            seen[kind] = true
            result[#result + 1] = kind
        end
    end

    for _, kind in ipairs(definition.appearanceTypeIDs or {}) do Add(kind) end
    for _, option in ipairs(definition.editorOptions or {}) do
        local id = type(option) == "table" and option.id or option
        Add(ROW_FAMILY_OPTION_KIND[id])
    end
    if definition.rowFamily == "sectionRow" then Add("TEXT") end
    return result
end

local function MakeRowFamilyMember(elementID, definition, kind, surface)
    local suffix = surface and "Surface" or kind:gsub("[^%w_%-]", "")
    local member = {
        id = elementID .. "." .. suffix,
        kind = surface and "BUTTON" or kind,
        role = surface and "PRIMARY" or "SECONDARY",
        label = surface and ((definition.label or elementID) .. " Surface")
            or (kind:sub(1, 1) .. kind:sub(2):lower()),
        appearanceWindowID = definition.appearanceWindowID,
        appearanceID = elementID .. "." .. suffix,
        appearanceParentID = surface
            and (definition.rowFamilyTagAppearanceID or elementID)
            or (elementID .. "." .. suffix),
        targets = function(element, current)
            return NSkin:GetRowFamilyMemberTargets(element, current)
        end,
        movementFamilyID = surface and "ROW_SURFACE" or ("ROW_" .. kind),
        movable = false,
        allowOverrides = surface == true,
        highlightMode = "REGIONS",
    }
    if surface then
        member.editorSurface = true
        member.rowFamilySurface = true
        member.surfaceStyle = definition.rowFamily
        member.editorOptions = GetRowFamilySurfaceOptions()
        for key, value in pairs(
            definition.rowFamilySurfaceDefinition or {})
        do
            member[key] = value
        end
    else
        local memberDefinitions = definition.rowFamilyMemberDefinitions
        local memberDefinition = memberDefinitions and memberDefinitions[kind]
        for key, value in pairs(memberDefinition or {}) do
            member[key] = value
        end
    end
    return member
end

function NSkin:PrepareRowFamilyDefinition(elementID, definition)
    if type(definition) ~= "table" then return false end
    local family = definition.rowFamily
    if not family and definition.kind == "ROW" then family = "row" end
    if not family and definition.kind == "SECTION_ROW" then
        family = "sectionRow"
    end
    if family ~= "row" and family ~= "sectionRow" then return false end

    definition.rowFamily = family
    definition.kind = "BUTTON"

    local composition = definition.composition
    if type(composition) ~= "table" or composition.mode ~= "COMPOSITE" then
        composition = {
            mode = "COMPOSITE",
            type = "REGULAR",
            editorLabel = definition.label,
            members = {},
        }
        definition.composition = composition
    else
        composition.type = "REGULAR"
        composition.members = composition.members or {}
    end
    -- Repeated/pooled row families are disjoint editor regions. Empty space
    -- between visible rows is not part of the Composite hit surface.
    composition.separateRegions = true
    composition.tag = composition.tag
        or (family == "sectionRow" and "Header Row" or "Row")
    local tagAppearanceID = NSkin.GetCompositeTagAppearanceID
        and NSkin:GetCompositeTagAppearanceID(composition.tag)
    definition.rowFamilyTagAppearanceID = tagAppearanceID
    if tagAppearanceID and NSkin.RegisterAppearanceParentID then
        NSkin:RegisterAppearanceParentID(
            elementID, tagAppearanceID, elementID)
    end

    local surface
    for _, member in ipairs(composition.members) do
        local memberFamily = member.rowFamily
        if not memberFamily and member.kind == "ROW" then memberFamily = "row" end
        if not memberFamily and member.kind == "SECTION_ROW" then
            memberFamily = "sectionRow"
        end
        if memberFamily == "row" or memberFamily == "sectionRow" then
            member.kind = "BUTTON"
            member.rowFamily = nil
            member.editorSurface = true
            member.rowFamilySurface = true
            member.surfaceStyle = family
            member.highlightMode = "REGIONS"
            member.movable = false
            member.allowOverrides = true
            member.movementFamilyID = "ROW_SURFACE"
            member.appearanceWindowID =
                member.appearanceWindowID or definition.appearanceWindowID
            member.appearanceID = member.appearanceID
                or (elementID .. ".Surface")
            member.appearanceParentID =
                definition.rowFamilyTagAppearanceID or elementID
            member.editorOptions = GetRowFamilySurfaceOptions()
            surface = member
        end
    end
    if not surface then
        table.insert(composition.members, 1,
            MakeRowFamilyMember(elementID, definition, "BUTTON", true))
    end

    local existingKinds = {}
    for _, member in ipairs(composition.members) do
        if not member.rowFamilySurface then existingKinds[member.kind] = true end
    end
    for _, kind in ipairs(CollectRowFamilyKinds(definition)) do
        if not existingKinds[kind] then
            composition.members[#composition.members + 1] =
                MakeRowFamilyMember(elementID, definition, kind, false)
            existingKinds[kind] = true
        end
    end

    local filtered = {}
    for _, kind in ipairs(definition.appearanceTypeIDs or {}) do
        if kind ~= "ROW" and kind ~= "SECTION_ROW" then
            filtered[#filtered + 1] = kind
        end
    end
    definition.appearanceTypeIDs = #filtered > 0 and filtered or nil

    -- Composite members now own contextual Skinning Mode presentation.
    -- Keep the old list only as source material for member construction.
    definition.editorOptions = {}
    return true
end

function NSkin:SkinColumnHeader(target, options)
    if not target or not target.CreateTexture
        or (target.IsForbidden and target:IsForbidden())
    then return nil end
    options = options or {}
    local style = options.style or self:GetStyle("columnHeader")
    if not style then return nil end
    local state = self:GetSkinData(target, COLUMN_HEADER_STATE)
    local visualRegion = ResolveContentValue(options.visualRegion, target)
    if not (visualRegion and visualRegion.GetObjectType) then
        visualRegion = target
    end
    local backgroundColor = self:GetResolvedAppearanceColor(
        style, "background")
    local borderColor = options.border
        or self:GetComponentBorderColor("columnHeader", style)
    local background = self:CreateFlatBackground(
        target, COLUMN_HEADER_BACKGROUND, backgroundColor, borderColor)
    if background and background.SetDrawLayer then
        background:SetDrawLayer("BACKGROUND", -8)
    end
    AnchorContentSurface(background, visualRegion, 1)
    local border = self:GetPixelBorder(
        target, COLUMN_HEADER_BACKGROUND .. "Border")
    if border then border.anchor = visualRegion end
    self:SetPixelBorderSize(border, style.borderSize or 1)
    self:SetPixelBorderPadding(border, style.borderPadding or 0)

    local textRegion = ResolveContentValue(options.textRegion, target)
        or target.Name or target.Text
        or (target.GetFontString and target:GetFontString())
    if textRegion then
        self:SetFontStringColor(textRegion, unpack(
            self:GetResolvedAppearanceColor(style, "text")))
        self:ApplyResolvedTypography(textRegion, style)
        if not state.originalJustifyH and textRegion.GetJustifyH then
            state.originalJustifyH = textRegion:GetJustifyH()
        end
        local alignment = string.upper(tostring(style.alignment or "BLIZZARD"))
        if textRegion.SetJustifyH then
            textRegion:SetJustifyH(alignment == "BLIZZARD"
                and state.originalJustifyH or alignment)
        end
    end
    local preserved = { [background] = true }
    PreserveContentRegions(preserved, options.preserveTextures)
    SuppressDeclaredContentArtwork(options.artworkRegions, preserved)
    if target.IsObjectType and target:IsObjectType("Button") then
        self:CreateFlatButtonGlow(target, style.hoverAlpha)
    end
    return state
end

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
    return preserved
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
    if not data or not data.active or data.enforcing or not data.style then
        return
    end
    data.enforcing = true
    if data.color and textRegion.SetTextColor then
        NSkin:SetFontStringColor(textRegion, unpack(data.color))
    end
    NSkin:ApplyResolvedTypography(textRegion, data.style)
    data.enforcing = nil
end

local function ConfigureSectionCardTextAppearance(textRegion, style, color)
    local data = NSkin:GetSkinData(textRegion, SECTION_CARD_TEXT_STATE)
    if not data.originalColor and textRegion.GetTextColor then
        data.originalColor = { textRegion:GetTextColor() }
    end
    if not data.originalFont and textRegion.GetFont then
        data.originalFont = { textRegion:GetFont() }
    end
    data.active = true
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

local function RestoreSectionCardTextAppearance(textRegion)
    local data = textRegion and NSkin:GetSkinData(
        textRegion, SECTION_CARD_TEXT_STATE, false)
    if not data or not data.active then return end
    data.active = nil
    data.enforcing = true
    if data.originalColor and textRegion.SetTextColor then
        textRegion:SetTextColor(unpack(data.originalColor))
    end
    if data.originalFont and textRegion.SetFont then
        textRegion:SetFont(unpack(data.originalFont))
    end
    data.enforcing = nil
end

local function RefreshSectionCardPresentation(target)
    local state = NSkin:GetSkinData(target, SECTION_CARD_STATE, false)
    if not state or not state.active then return end
    if state.textRegion then
        EnforceSectionCardTextAppearance(state.textRegion)
    end
    if state.glow then
        local highlighted = false
        if state.showHighlight then
            local hovered
            if state.interactionManaged then
                hovered = ResolveContentState(
                    state.getHovered, state.hoverRegion, target)
            else
                hovered = target.IsMouseOver
                    and target:IsMouseOver() == true or false
            end
            local selected = ResolveContentState(
                state.getSelected, state.selectedRegion, target)
            highlighted = hovered or selected
        end
        state.glow:SetShown(highlighted)
    end
    RefreshSectionCardGlyph(target)
end

local function RestoreSectionCardHoverRegion(regionState)
    if not regionState or not regionState.region then return end
    RestoreContentStateRegion(regionState)
end

local function ConcealSectionCardHoverRegion(target, state)
    local regionState = state.hoverRegionState
    if not state.active or not regionState or not regionState.active
        or regionState.applying
    then return end
    regionState.applying = true
    if regionState.region.SetAlpha then regionState.region:SetAlpha(0)
    elseif regionState.region.Hide then regionState.region:Hide() end
    regionState.applying = nil
end

local function ApplySectionCardHoverRegion(target, state, region)
    local previous = state.hoverRegionState
    if previous and previous.active and previous.region ~= region then
        RestoreSectionCardHoverRegion(previous)
    end
    if not region then
        state.hoverRegionState = nil
        return
    end
    local regionState = previous and previous.region == region and previous
        or {
            region = region,
            alpha = region.GetAlpha and region:GetAlpha() or 1,
            shown = region.IsShown and region:IsShown() or nil,
        }
    state.hoverRegionState = regionState
    regionState.active = true
    ConcealSectionCardHoverRegion(target, state)
    if not regionState.hooked and _G.hooksecurefunc then
        local function MaintainHoverRegion()
            ConcealSectionCardHoverRegion(target, state)
            RefreshSectionCardPresentation(target)
        end
        for _, method in ipairs({ "SetAlpha", "SetShown", "Show", "Hide" }) do
            if type(region[method]) == "function" then
                pcall(_G.hooksecurefunc, region, method, MaintainHoverRegion)
            end
        end
        regionState.hooked = true
    end
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
    local state = self:GetSkinData(target, SECTION_CARD_STATE)
    if options.reset == true then
        state.active = nil
        if state.heightModified and state.originalHeight and target.SetHeight then
            target:SetHeight(state.originalHeight)
            state.heightModified = nil
        end
        for _, regionState in pairs(state.nativeDecorationStates or {}) do
            if regionState.active then RestoreContentStateRegion(regionState) end
        end
        if state.hoverRegionState and state.hoverRegionState.active then
            RestoreSectionCardHoverRegion(state.hoverRegionState)
        end
        RestoreSectionCardTextAppearance(state.textRegion)
        if state.background then state.background:Hide() end
        if state.border then self:SetPixelBorderShown(state.border, false) end
        if state.glow then state.glow:Hide() end
        if state.glyph then state.glyph:Hide() end
        return state
    end
    local style = options.style or self:GetStyle("sectionCard")
    if not style then return nil end
    state.active = true
    state.options = options
    state.collapsible = options.collapsible == true
    state.getHovered = options.getHovered
    state.getSelected = options.getSelected
    state.showHighlight = style.showHighlight ~= false
    state.hoverRegion = ResolveSectionCardValue(options.hoverRegion, target)
    state.selectedRegion = ResolveSectionCardValue(
        options.selectedRegion, target)
    state.interactionManaged = options.getHovered ~= nil
        or options.hoverRegion ~= nil or options.getSelected ~= nil
        or options.selectedRegion ~= nil
    local visualRegion = ResolveSectionCardValue(options.visualRegion, target)
    if not (visualRegion and visualRegion.GetObjectType) then
        visualRegion = target
    end
    state.visualRegion = visualRegion
    local presentationOwner = ResolveSectionCardValue(
        options.presentationOwner, target)
    if not (presentationOwner and presentationOwner.CreateTexture) then
        presentationOwner = target
    end
    if state.presentationOwner
        and state.presentationOwner ~= presentationOwner
    then
        if state.background then state.background:Hide() end
        if state.border then self:SetPixelBorderShown(state.border, false) end
        if state.glow then state.glow:Hide() end
        state.background = nil
        state.border = nil
        state.glow = nil
    end
    state.presentationOwner = presentationOwner

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
    local showBackground = options.showBackground ~= false
    local background = self:GetFlatBackground(
        presentationOwner, SECTION_CARD_BACKGROUND)
    if showBackground then
        background = self:CreateFlatBackground(
            presentationOwner, SECTION_CARD_BACKGROUND,
            backgroundColor, borderColor)
        AnchorSectionCardSurface(background, visualRegion, 1)
        background:Show()
    elseif background then
        background:Hide()
    end
    local border = self:GetPixelBorder(
        presentationOwner, SECTION_CARD_BACKGROUND .. "Border")
    if not border then
        border = self:CreatePixelBorder(
            presentationOwner, SECTION_CARD_BACKGROUND .. "Border",
            style.borderSize or 1, borderColor, false, visualRegion)
    end
    state.background = background
    state.border = border
    if border then border.anchor = visualRegion end
    self:SetPixelBorderColor(border, unpack(borderColor))
    self:SetPixelBorderSize(border, style.borderSize or 1)
    self:SetPixelBorderPadding(border, style.borderPadding or 0)
    self:SetPixelBorderShown(border,
        style.showBorder ~= false and (tonumber(style.borderSize) or 0) > 0)
    local glow = self:CreateFlatButtonGlow(
        presentationOwner, style.hoverAlpha, true)
    AnchorSectionCardSurface(glow, visualRegion, 1)
    state.glow = glow
    ApplySectionCardHoverRegion(target, state,
        state.interactionManaged and state.hoverRegion or nil)

    local icon = ResolveSectionCardValue(options.icon, target)
    local preserved = SuppressSectionCardArtwork(
        target, options, icon, background, border, glow)
    ApplyRowNativeDecorations(target, state,
        options.nativeDecorationRegions or options.artworkRegions, preserved)

    local textRegion = ResolveSectionCardText(target, state, options)
    if state.textRegion and state.textRegion ~= textRegion then
        RestoreSectionCardTextAppearance(state.textRegion)
    end
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
        self:SetOwnedTextureColor(glyph.horizontal, unpack(glyphColor))
        glyph.vertical:ClearAllPoints()
        glyph.vertical:SetPoint("TOP", glyph, "TOP", 0, 0)
        glyph.vertical:SetPoint("BOTTOM", glyph, "BOTTOM", 0, 0)
        glyph.vertical:SetWidth(strokeSize)
        self:SetOwnedTextureColor(glyph.vertical, unpack(glyphColor))
    elseif state.glyph then
        state.glyph:Hide()
    end

    if not state.presentationHooksInstalled and target.HookScript then
        for _, script in ipairs({ "OnShow", "OnEnter", "OnLeave" }) do
            target:HookScript(script, RefreshSectionCardPresentation)
        end
        state.presentationHooksInstalled = true
    end
    if not state.selectionHooksInstalled and _G.hooksecurefunc then
        for _, method in ipairs({ "SetSelected", "SetChecked" }) do
            if type(target[method]) == "function" then
                pcall(_G.hooksecurefunc, target, method,
                    RefreshSectionCardPresentation)
            end
        end
        state.selectionHooksInstalled = true
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

function NSkin:GetIconTexCoords(width, height, zoom)
    width = math.max(tonumber(width) or 1, 0.001)
    height = math.max(tonumber(height) or 1, 0.001)
    zoom = math.max(0, math.min(0.49, tonumber(zoom) or 0))

    local visibleSpan = 1 - (zoom * 2)
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
    circle = {
        applyTexCoords = function(texture, width, height, zoom, crop)
            texture:SetTexCoord(NSkin:GetIconTexCoords(
                width, height, zoom, crop))
        end,
        configureMask = function(mask)
            mask:SetAtlas("talents-node-circle-mask", false)
        end,
    },
    hexagon = {
        applyTexCoords = function(texture, width, height, zoom, crop)
            texture:SetTexCoord(NSkin:GetIconTexCoords(
                width, height, zoom, crop))
        end,
        configureMask = function(mask)
            mask:SetTexture(
                "Interface\\AddOns\\NSkin\\Media\\Masks\\icon-mask-hexagon.tga")
        end,
        borderTexture = "Interface\\AddOns\\NSkin\\Media\\Borders\\icon-border-hexagon.tga",
    },
    octagon = {
        applyTexCoords = function(texture, width, height, zoom, crop)
            texture:SetTexCoord(NSkin:GetIconTexCoords(
                width, height, zoom, crop))
        end,
        configureMask = function(mask)
            mask:SetTexture(
                "Interface\\AddOns\\NSkin\\Media\\Masks\\icon-mask-octagon.tga")
        end,
        borderTexture = "Interface\\AddOns\\NSkin\\Media\\Borders\\icon-border-octagon.tga",
    },
}

local function ResolveIconShape(style, options)
    local explicitShape = options.shape
    if explicitShape ~= nil then
        explicitShape = string.lower(tostring(explicitShape))
        return ICON_SHAPES[explicitShape] and explicitShape or "square"
    end
    local styleShape = string.lower(tostring(style.shape or "square"))
    if not ICON_SHAPES[styleShape] then styleShape = "square" end
    local baseShape = NSkin.baseAppearance and NSkin.baseAppearance.icon
        and NSkin.baseAppearance.icon.shape or "square"
    if style.shapeMode == "CUSTOM" or styleShape ~= baseShape then
        return styleShape
    end
    local defaultShape = options.defaultShape
    if defaultShape ~= nil then
        defaultShape = string.lower(tostring(defaultShape))
        if ICON_SHAPES[defaultShape] then return defaultShape end
    end
    return styleShape
end

local function HasIconMask(texture, mask)
    if not texture or not mask or not texture.GetNumMaskTextures
        or not texture.GetMaskTexture
    then return false end
    for index = 1, texture:GetNumMaskTextures() do
        if texture:GetMaskTexture(index) == mask then return true end
    end
    return false
end

local function ClearIconCropMask(data)
    local texture = data and data.cropMaskTexture
    local mask = data and data.cropMask
    if texture and mask and texture.RemoveMaskTexture
        and HasIconMask(texture, mask)
    then
        texture:RemoveMaskTexture(mask)
    end
    if data then
        data.cropMaskAdded = nil
        data.cropMaskTexture = nil
    end
end

local function ApplyIconCropMask(data, owner, texture)
    if not data or not owner or not texture then return false end
    local crop = math.max(0.01, math.min(1, tonumber(data.crop) or 1))
    if crop >= 0.9999 then
        ClearIconCropMask(data)
        return true
    end
    if not owner.CreateMaskTexture or not texture.AddMaskTexture then
        return false
    end

    if data.cropMaskOwner ~= owner then
        ClearIconCropMask(data)
        data.cropMasksByOwner = data.cropMasksByOwner
            or setmetatable({}, { __mode = "k" })
        data.cropMask = data.cropMasksByOwner[owner]
        data.cropMaskOwner = owner
    end
    local mask = data.cropMask
    if not mask then
        mask = owner:CreateMaskTexture(nil, "ARTWORK")
        data.cropMask = mask
        data.cropMasksByOwner[owner] = mask
    end
    -- Solid rectangular masks must clamp to transparent outside their own
    -- bounds. Without CLAMPTOBLACKADDITIVE, WHITE8X8 can sample its opaque
    -- edge indefinitely and the mask effectively covers the full icon.
    mask:SetTexture("Interface\\Buttons\\WHITE8X8",
        "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    if mask.SetTexelSnappingBias then mask:SetTexelSnappingBias(0) end
    if mask.SetSnapToPixelGrid then mask:SetSnapToPixelGrid(false) end
    mask:Show()

    local width = texture.GetWidth and texture:GetWidth() or 0
    local height = texture.GetHeight and texture:GetHeight() or 0
    if width <= 0 or height <= 0 then return false end
    mask:ClearAllPoints()
    mask:SetPoint("CENTER", texture, "CENTER", 0, 0)
    mask:SetSize(width, height * crop)

    if not HasIconMask(texture, mask) then
        texture:AddMaskTexture(mask)
    end
    data.cropMaskAdded = true
    data.cropMaskTexture = texture
    return true
end

local function ClearIconShapeMask(data)
    -- A reused ICON can change both its texture and its border owner. Remove
    -- every NSkin-created mask from either presentation texture before reuse.
    local textures, masks = {}, {}
    if data.shapeIconMaskTexture then
        textures[#textures + 1] = data.shapeIconMaskTexture
    end
    if data.texture and data.texture ~= data.shapeIconMaskTexture then
        textures[#textures + 1] = data.texture
    end
    if data.shapeIconMask then masks[#masks + 1] = data.shapeIconMask end
    for _, mask in pairs(data.shapeIconMasksByOwner or {}) do
        masks[#masks + 1] = mask
    end
    for _, texture in ipairs(textures) do
        if texture and texture.RemoveMaskTexture then
            for _, mask in ipairs(masks) do
                if HasIconMask(texture, mask) then
                    texture:RemoveMaskTexture(mask)
                end
            end
        end
    end
    data.shapeIconMaskAdded = nil
    data.shapeIconMaskTexture = nil
end

local function DeactivateIconShape(data)
    ClearIconShapeMask(data)
    for _, border in pairs(data.shapeBorderSets or {}) do
        if border.backing then
            border.backing:Hide()
            if HasIconMask(border.backing, border.mask) then
                border.backing:RemoveMaskTexture(border.mask)
            end
            border.backing:SetRotation(0)
            border.backing:SetTexture(nil)
            local colorState = NSkin:GetSkinData(
                border.backing, "ownedTextureColor", false)
            if colorState then colorState.color = nil end
        end
        for _, segment in ipairs(border.segments or {}) do
            segment:Hide()
            if border.cropMask and HasIconMask(segment, border.cropMask) then
                segment:RemoveMaskTexture(border.cropMask)
            end
        end
    end
    data.activeShape = nil
end

local function ApplyIconNativeMask(data)
    local texture = data.texture
    local mask = data.nativeMask
    if not texture or not mask then return end
    if data.suppressNativeMask then
        if HasIconMask(texture, mask) and texture.RemoveMaskTexture then
            texture:RemoveMaskTexture(mask)
            data.nativeMaskRemoved = true
        end
    elseif data.nativeMaskRemoved then
        if not HasIconMask(texture, mask) and texture.AddMaskTexture then
            texture:AddMaskTexture(mask)
        end
        data.nativeMaskRemoved = nil
    end
end

local function ConfigureIconShapeMask(mask, shape, anchor, explicitSize)
    local definition = ICON_SHAPES[shape]
    if not mask or not definition or not definition.configureMask
        or not anchor or not anchor.GetWidth or not anchor.GetHeight
    then return false end
    local size = tonumber(explicitSize)
        or math.min(anchor:GetWidth() or 0, anchor:GetHeight() or 0)
    if size <= 0 then return false end
    mask:ClearAllPoints()
    mask:SetPoint("CENTER", anchor, "CENTER", 0, 0)
    mask:SetSize(size, size)
    definition.configureMask(mask)
    return true
end

local function EnsureIconShapeMask(self, data, owner, texture)
    if data.shape == "square" then return true end
    if not owner.CreateMaskTexture or not texture.AddMaskTexture then
        return false
    end
    if data.shapeIconMaskOwner ~= owner then
        ClearIconShapeMask(data)
        data.shapeIconMasksByOwner = data.shapeIconMasksByOwner
            or setmetatable({}, { __mode = "k" })
        data.shapeIconMask = data.shapeIconMasksByOwner[owner]
        data.shapeIconMaskOwner = owner
    end
    if not data.shapeIconMaskAdded then
        local mask = data.shapeIconMask
        if not mask then
            mask = owner:CreateMaskTexture(nil, "ARTWORK")
            data.shapeIconMask = mask
            data.shapeIconMasksByOwner[owner] = mask
        end
        if not ConfigureIconShapeMask(mask, data.shape, texture) then
            return false
        end
        texture:AddMaskTexture(mask)
        data.shapeIconMaskAdded = true
        data.shapeIconMaskTexture = texture
    else
        ConfigureIconShapeMask(data.shapeIconMask, data.shape, texture)
    end
    return true
end

local function HideIconShapeBorder(data)
    if data.shapeBorderBacking then data.shapeBorderBacking:Hide() end
    local set = data.shapeBorderSets
        and data.shapeBorderSets[data.shapeBorderOwner]
    for _, segment in ipairs(set and set.segments or {}) do
        segment:Hide()
    end
end

local ICON_SHAPE_EDGE_SCALE = {
    -- Measured from the shipped 256x256 alpha masks.
    hexagon = { x = 0.859375, y = 1 },
    octagon = { x = 0.921875, y = 0.921875 },
}

local function GetIconShapeBorderVertices(shape, halfWidth, halfHeight, padding)
    local scale = ICON_SHAPE_EDGE_SCALE[shape]
    halfWidth = halfWidth * (scale and scale.x or 1) + (padding or 0)
    halfHeight = halfHeight * (scale and scale.y or 1) + (padding or 0)
    if shape == "square" then
        return {
            { -halfWidth, -halfHeight },
            { halfWidth, -halfHeight },
            { halfWidth, halfHeight },
            { -halfWidth, halfHeight },
        }
    elseif shape == "hexagon" then
        return {
            { 0, -halfHeight },
            { halfWidth, -halfHeight * 0.5 },
            { halfWidth, halfHeight * 0.5 },
            { 0, halfHeight },
            { -halfWidth, halfHeight * 0.5 },
            { -halfWidth, -halfHeight * 0.5 },
        }
    elseif shape == "octagon" then
        local corner = math.sqrt(2) - 1
        return {
            { -halfWidth * corner, -halfHeight },
            { halfWidth * corner, -halfHeight },
            { halfWidth, -halfHeight * corner },
            { halfWidth, halfHeight * corner },
            { halfWidth * corner, halfHeight },
            { -halfWidth * corner, halfHeight },
            { -halfWidth, halfHeight * corner },
            { -halfWidth, -halfHeight * corner },
        }
    end

    -- 24 segments are visually smooth at icon scale while avoiding the
    -- per-slider-frame cost of the previous 48-segment circle.
    local vertices = {}
    local segments = 24
    for index = 0, segments - 1 do
        local angle = -math.pi / 2 + index * math.pi * 2 / segments
        vertices[#vertices + 1] = {
            math.cos(angle) * halfWidth,
            math.sin(angle) * halfHeight,
        }
    end
    return vertices
end

local function ClipIconBorderPolygonY(vertices, minY, maxY)
    local function ClipEdge(input, boundary, keepAbove)
        local output = {}
        if #input == 0 then return output end
        local previous = input[#input]
        local previousInside = (keepAbove and previous[2] >= boundary)
            or (not keepAbove and previous[2] <= boundary)
        for _, current in ipairs(input) do
            local currentInside = (keepAbove and current[2] >= boundary)
                or (not keepAbove and current[2] <= boundary)
            if currentInside ~= previousInside then
                local dy = current[2] - previous[2]
                local ratio = dy ~= 0 and (boundary - previous[2]) / dy or 0
                output[#output + 1] = {
                    previous[1] + (current[1] - previous[1]) * ratio,
                    boundary,
                }
            end
            if currentInside then
                output[#output + 1] = { current[1], current[2] }
            end
            previous = current
            previousInside = currentInside
        end
        return output
    end

    vertices = ClipEdge(vertices, minY, true)
    return ClipEdge(vertices, maxY, false)
end

local function EnsureIconShapeBorder(data, owner, texture)
    if not owner or not owner.CreateTexture or not texture then return false end
    data.shapeBorderSets = data.shapeBorderSets
        or setmetatable({}, { __mode = "k" })
    if data.shapeBorderOwner ~= owner then
        HideIconShapeBorder(data)
        data.shapeBorderOwner = owner
    end
    local set = data.shapeBorderSets[owner]
    if not set then
        set = { segments = {} }
        data.shapeBorderSets[owner] = set
    end
    data.shapeBorderSegments = set.segments
    return true
end

local function ApplyIconShapeBorderGeometry(self, data, texture, shown, color)
    local owner = data.shapeBorderOwner
    local set = owner and data.shapeBorderSets
        and data.shapeBorderSets[owner]
    if not set or not texture then return false end

    local pixel = self:GetPhysicalPixelSize(texture)
    local borderSize = math.max(1, tonumber(data.borderSize) or 1)
    local thickness = self:SnapToPhysicalPixel(
        texture, borderSize * pixel)
    local padding = self:SnapToPhysicalPixel(
        texture, (tonumber(data.borderPadding) or 0) * pixel)
    local width = texture.GetWidth and texture:GetWidth() or 0
    local height = texture.GetHeight and texture:GetHeight() or 0
    if width <= 0 or height <= 0 then return false end

    local vertices = GetIconShapeBorderVertices(
        data.shape, width / 2, height / 2, padding)
    local crop = math.max(0.01, math.min(1,
        tonumber(data.borderCrop) or tonumber(data.crop) or 1))
    local edgeScale = ICON_SHAPE_EDGE_SCALE[data.shape]
    local baseHalfHeight = height / 2 * (edgeScale and edgeScale.y or 1)
    local cropHalfHeight = baseHalfHeight * crop + padding
    vertices = ClipIconBorderPolygonY(
        vertices, -cropHalfHeight, cropHalfHeight)
    local needed = #vertices

    for index = 1, needed do
        local segment = set.segments[index]
        if not segment then
            segment = owner:CreateTexture(nil, "OVERLAY", nil, 7)
            self:ConfigureOwnedPixelTexture(segment)
            set.segments[index] = segment
        end

        local first = vertices[index]
        local second = vertices[index % needed + 1]
        local dx, dy = second[1] - first[1], second[2] - first[2]
        local length = math.sqrt(dx * dx + dy * dy)
        if length > 0 then
            local midpointX = (first[1] + second[1]) / 2
            local midpointY = (first[2] + second[2]) / 2
            segment:ClearAllPoints()
            segment:SetPoint("CENTER", texture, "CENTER",
                midpointX, midpointY)
            -- Border size is centered on the shape edge so it grows equally
            -- inward and outward. The small length overlap prevents pinholes
            -- at polygon corners without changing the path itself.
            segment:SetSize(length + thickness * 0.35, thickness)
            segment:SetRotation(math.atan2(dy, dx))
            self:SetOwnedTextureColor(segment, unpack(color))
            segment:SetShown(shown)
        else
            segment:Hide()
        end
    end
    for index = needed + 1, #set.segments do
        set.segments[index]:Hide()
    end
    return true
end

local function ResolveIconNativeDecorationRegions(value, target, texture)
    if type(value) == "function" then
        local ok, resolved = pcall(value, target, texture)
        value = ok and resolved or nil
    end
    if not value then return {} end
    if value.GetObjectType then return { value } end
    return type(value) == "table" and value or {}
end

local function RestoreIconNativeDecoration(state)
    local region = state and state.region
    if not region then return end
    state.active = nil
    state.applying = true
    if region.SetAlpha and state.alpha ~= nil then
        region:SetAlpha(state.alpha)
    end
    if region.SetShown and state.shown ~= nil then
        region:SetShown(state.shown)
    elseif state.shown == true and region.Show then
        region:Show()
    elseif state.shown == false and region.Hide then
        region:Hide()
    end
    state.applying = nil
end

local function ConcealIconNativeDecoration(data, state)
    local region = state and state.region
    if not data.active or not state.active or state.applying
        or not region
    then return end
    state.applying = true
    if region.SetAlpha then region:SetAlpha(0)
    elseif region.Hide then region:Hide() end
    state.applying = nil
end

local function ApplyIconNativeDecorations(data, target, texture, declared)
    data.nativeDecorationDeclaration = declared
    local activeRegions = {}
    for _, region in ipairs(ResolveIconNativeDecorationRegions(
        declared, target, texture))
    do
        if region then activeRegions[region] = true end
    end

    data.nativeDecorationStates = data.nativeDecorationStates
        or data.nativeBorderStates or {}
    data.nativeBorderStates = nil
    for region, state in pairs(data.nativeDecorationStates) do
        if state.active and not activeRegions[region] then
            RestoreIconNativeDecoration(state)
        end
    end
    for region in pairs(activeRegions) do
        local state = data.nativeDecorationStates[region]
        if not state then
            local shown
            if region.IsShown then shown = region:IsShown() end
            state = {
                region = region,
                alpha = region.GetAlpha and region:GetAlpha() or 1,
                shown = shown,
            }
            data.nativeDecorationStates[region] = state
        end
        state.active = true
        ConcealIconNativeDecoration(data, state)
        if not state.hooked and _G.hooksecurefunc then
            local function MaintainNativeDecoration()
                ConcealIconNativeDecoration(data, state)
            end
            for _, method in ipairs({ "SetAlpha", "SetShown", "Show" }) do
                if type(region[method]) == "function" then
                    pcall(_G.hooksecurefunc, region, method,
                        MaintainNativeDecoration)
                end
            end
            state.hooked = true
        end
    end
end

local function GetIconButtonStateTexture(target, method, ...)
    if not target then return nil end
    if type(target[method]) == "function" then
        local ok, region = pcall(target[method], target)
        if ok and region then return region end
    end
    for index = 1, select("#", ...) do
        local region = target[select(index, ...)]
        if region then return region end
    end
end

local function ResolveIconInteractionRegion(value, target, texture)
    if type(value) ~= "function" then return value end
    local ok, region = pcall(value, target, texture)
    return ok and region or nil
end

local function IsIconTargetHovered(target)
    return target and target.IsMouseOver and target:IsMouseOver() or false
end

local function RestoreIconInteractionRegion(state)
    local region = state and state.region
    if not region then return end
    state.active = nil
    state.applying = true
    if region.SetAlpha and state.alpha ~= nil then
        region:SetAlpha(state.alpha)
    end
    if region.SetShown and state.shown ~= nil then
        region:SetShown(state.shown)
    elseif state.shown == true and region.Show then
        region:Show()
    elseif state.shown == false and region.Hide then
        region:Hide()
    end
    state.applying = nil
end

local function ResolveIconInteractionState(provider, fallback, target)
    if type(provider) == "function" then
        local ok, value = pcall(provider, target)
        if ok then return value == true end
    end
    return fallback and fallback.IsShown and fallback:IsShown() == true
        or false
end

local function RefreshIconInteractionGlow(target)
    local data = NSkin:GetSkinData(target, ICON_COMPONENT_STATE, false)
    local glow = data and data.interactionGlow
    if not glow then return end
    if not data.active or not data.interactionActive
        or (target.IsEnabled and not target:IsEnabled())
    then
        glow:Hide()
        return
    end
    local hovered = ResolveIconInteractionState(
        data.getHovered, data.hoverRegion, target)
    local selected = ResolveIconInteractionState(
        data.getSelected, data.selectedRegion, target)
    glow:SetShown(hovered or selected)
end

local function HideIconInteractionGlow(target)
    local data = NSkin:GetSkinData(target, ICON_COMPONENT_STATE, false)
    if data and data.interactionGlow then data.interactionGlow:Hide() end
end

local function ConcealIconInteractionRegion(data, state)
    local region = state and state.region
    if not data.active or not data.interactionActive or not state.active
        or state.applying or not region
    then return end
    state.applying = true
    if region.SetAlpha then region:SetAlpha(0)
    elseif region.Hide then region:Hide() end
    state.applying = nil
end

local function ApplyIconInteraction(self, data, target, texture, options)
    data.interactionOptions = options
    local configuredHover = ResolveIconInteractionRegion(
        options.hoverRegion, target, texture)
    local configuredHoverRegions = ResolveIconNativeDecorationRegions(
        options.hoverRegions, target, texture)
    local nativeHover = GetIconButtonStateTexture(target,
        "GetHighlightTexture", "HighlightTexture", "highlightTexture",
        "Highlight", "highlight")
    local hoverRegion = nativeHover or configuredHover
        or configuredHoverRegions[1]
    local selectedRegion = ResolveIconInteractionRegion(
        options.selectedRegion, target, texture)
    local active = hoverRegion ~= nil or selectedRegion ~= nil
        or type(options.getHovered) == "function"
        or type(options.getSelected) == "function"
    local presentationOwner = options.interactionOwner
        or options.borderOwner or data.borderOwner or target
    active = active and type(presentationOwner.CreateTexture) == "function"
        and type(self.CreateFlatButtonGlow) == "function"
    data.interactionActive = active
    data.hoverRegion = hoverRegion
    data.selectedRegion = selectedRegion
    data.getHovered = options.getHovered
        or (hoverRegion and IsIconTargetHovered or nil)
    data.getSelected = options.getSelected
    data.interactionRegionStates = data.interactionRegionStates or {}

    local declared = {}
    for _, region in ipairs(configuredHoverRegions) do
        declared[region] = true
    end
    if configuredHover then declared[configuredHover] = true end
    if hoverRegion then declared[hoverRegion] = true end
    if selectedRegion then declared[selectedRegion] = true end
    for region, state in pairs(data.interactionRegionStates) do
        if state.active and not declared[region] then
            RestoreIconInteractionRegion(state)
        end
    end
    for region in pairs(declared) do
        local state = data.interactionRegionStates[region]
        if not state then
            local shown
            if region.IsShown then shown = region:IsShown() end
            state = {
                region = region,
                alpha = region.GetAlpha and region:GetAlpha() or 1,
                shown = shown,
            }
            data.interactionRegionStates[region] = state
        end
        state.active = true
        ConcealIconInteractionRegion(data, state)
        if not state.hooked and _G.hooksecurefunc then
            local function RefreshInteractionRegion()
                ConcealIconInteractionRegion(data, state)
                RefreshIconInteractionGlow(target)
            end
            for _, method in ipairs({
                "SetAlpha", "SetShown", "Show", "Hide",
            }) do
                if type(region[method]) == "function" then
                    pcall(_G.hooksecurefunc, region, method,
                        RefreshInteractionRegion)
                end
            end
            state.hooked = true
        end
    end

    if not active then
        if data.interactionGlow then data.interactionGlow:Hide() end
        return
    end
    local buttonStyle = self:GetStyle("button") or {}
    local alpha = tonumber(options.interactionAlpha)
        or tonumber(buttonStyle.hoverAlpha) or 0.10
    local glowOwner = target
    if target.GetObjectType and target:GetObjectType() == "Texture" then
        if not _G.CreateFrame then return end
        local overlay = data.interactionOverlay
        if not overlay then
            overlay = _G.CreateFrame("Frame", nil, presentationOwner)
            overlay:EnableMouse(false)
            data.interactionOverlay = overlay
        elseif overlay:GetParent() ~= presentationOwner then
            overlay:SetParent(presentationOwner)
        end
        overlay:ClearAllPoints()
        overlay:SetAllPoints(texture)
        local level = presentationOwner.GetFrameLevel
            and presentationOwner:GetFrameLevel() or 0
        local textureParent = texture.GetParent and texture:GetParent()
        if textureParent and textureParent.GetFrameLevel then
            level = math.max(level, textureParent:GetFrameLevel())
        end
        overlay:SetFrameLevel(level + 1)
        glowOwner = overlay
    end
    local glow = self:CreateFlatButtonGlow(glowOwner, alpha, true)
    if not glow then return end
    glow:ClearAllPoints()
    local pixel = self:GetPhysicalPixelSize(texture)
    local inset = pixel * math.max(1,
        (data.borderPadding or 0) + (data.borderSize or 1))
    glow:SetPoint("TOPLEFT", texture, "TOPLEFT", inset, -inset)
    glow:SetPoint("BOTTOMRIGHT", texture, "BOTTOMRIGHT", -inset, inset)
    data.interactionGlow = glow
    if data.shape ~= "square" and glow.AddMaskTexture then
        local mask = data.interactionGlowMask
        if not mask and glowOwner.CreateMaskTexture then
            mask = glowOwner:CreateMaskTexture(nil, "OVERLAY")
            data.interactionGlowMask = mask
        end
        if mask and ConfigureIconShapeMask(mask, data.shape, glow) then
            if not data.interactionGlowMasked then
                glow:AddMaskTexture(mask)
                data.interactionGlowMasked = true
            end
        end
    elseif data.interactionGlowMasked and glow.RemoveMaskTexture then
        glow:RemoveMaskTexture(data.interactionGlowMask)
        data.interactionGlowMasked = nil
    end
    if not data.interactionHooksInstalled and target.HookScript then
        local function RefreshInteraction(shownTarget)
            RefreshIconInteractionGlow(shownTarget)
        end
        target:HookScript("OnEnter", RefreshInteraction)
        target:HookScript("OnLeave", RefreshInteraction)
        target:HookScript("OnShow", RefreshInteraction)
        target:HookScript("OnHide", HideIconInteractionGlow)
        data.interactionHooksInstalled = true
    end
    if not data.interactionMethodHooksInstalled and _G.hooksecurefunc then
        local function RefreshInteractionMethod(changedTarget)
            RefreshIconInteractionGlow(changedTarget)
        end
        for _, method in ipairs({
            "SetChecked", "SetEnabled", "SetHighlightTexture",
            "ClearHighlightTexture",
        }) do
            if type(target[method]) == "function" then
                if method == "SetHighlightTexture"
                    or method == "ClearHighlightTexture"
                then
                    pcall(_G.hooksecurefunc, target, method, function()
                        local state = NSkin:GetSkinData(
                            target, ICON_COMPONENT_STATE, false)
                        if state and state.active and state.interactionOptions then
                            ApplyIconInteraction(NSkin, state, target,
                                state.texture, state.interactionOptions)
                        end
                    end)
                else
                    pcall(_G.hooksecurefunc, target, method,
                        RefreshInteractionMethod)
                end
            end
        end
        data.interactionMethodHooksInstalled = true
    end
    RefreshIconInteractionGlow(target)
end

local function CanModifyIconPresentation(target)
    return target and not (target.IsForbidden and target:IsForbidden())
        and not (target.IsProtected and target:IsProtected() and InCombatLockdown())
end

-- Unknown masks are never removed. Always restore the exact attached set,
-- including when a client rejects the masked texcoord operation.
local function ApplyDeclaredIconMasks(texture, declared, allow, callback)
    if not CanModifyIconPresentation(texture) then return false end
    local count = texture.GetNumMaskTextures and texture:GetNumMaskTextures() or 0
    if count == 0 then return pcall(callback) end
    if not allow or not texture.GetMaskTexture then return false end
    local allowed, attached = {}, {}
    for _, mask in ipairs(declared or {}) do allowed[mask] = true end
    for i = 1, count do
        local mask = texture:GetMaskTexture(i)
        if not allowed[mask] or not CanModifyIconPresentation(mask) then return false end
        attached[i] = mask
    end
    for _, mask in ipairs(attached) do texture:RemoveMaskTexture(mask) end
    local ok = pcall(callback)
    for _, mask in ipairs(attached) do texture:AddMaskTexture(mask) end
    return ok
end

local function ApplyIconTexCoords(target)
    local data = NSkin:GetSkinData(target, ICON_COMPONENT_STATE, false)
    local texture = data and data.texture
    if not data or not data.active or data.applyingTexCoords
        or not texture or not texture.SetTexCoord
    then return end
    if data.preserveTexCoords then return end
    if data.preserveAtlasTexCoords and texture.GetAtlas
        and texture:GetAtlas()
    then return end
    -- Masked crop is opt-in and may touch only explicitly declared masks.
    local width = texture.GetWidth and texture:GetWidth() or data.width
    local height = texture.GetHeight and texture:GetHeight() or data.height
    local shape = ICON_SHAPES[data.shape] or ICON_SHAPES.square
    data.applyingTexCoords = true
    ApplyDeclaredIconMasks(texture, data.nativeMasks,
        data.allowMaskedTexCoords, function()
            if data.textureBaselineID then
                NSkin:MarkComponentGeometryModified(
                    data.textureBaselineID, "texCoords", true)
            end
            shape.applyTexCoords(texture, width, height, data.zoom)
        end)
    data.applyingTexCoords = nil
end

local function ApplyIconGeometry(target)
    local data = NSkin:GetSkinData(target, ICON_COMPONENT_STATE, false)
    local texture = data and data.texture
    if not data or not data.active or not data.geometryOwned
        or data.applyingGeometry or not texture
    then return end
    local width, height = data.presentationWidth, data.presentationHeight
    if not width or not height then return end
    if data.geometryPoint and texture.ClearAllPoints and texture.SetPoint then
        local pointMatches = texture.GetNumPoints
            and texture:GetNumPoints() == 1
        if pointMatches and texture.GetPoint then
            local point, relativeTo, relativePoint, xOffset, yOffset =
                texture:GetPoint(1)
            pointMatches = point == data.geometryPoint[1]
                and relativeTo == data.geometryPoint[2]
                and relativePoint == data.geometryPoint[3]
                and xOffset == data.geometryPoint[4]
                and yOffset == data.geometryPoint[5]
        end
        if not pointMatches then
            data.applyingGeometry = true
            texture:ClearAllPoints()
            texture:SetPoint(
                data.geometryPoint[1], data.geometryPoint[2],
                data.geometryPoint[3], data.geometryPoint[4],
                data.geometryPoint[5])
            data.applyingGeometry = nil
        end
    end
    local currentWidth = texture.GetWidth and texture:GetWidth()
    local currentHeight = texture.GetHeight and texture:GetHeight()
    if currentWidth == width and currentHeight == height then return end
    data.applyingGeometry = true
    if texture.SetSize then texture:SetSize(width, height)
    else
        if texture.SetWidth then texture:SetWidth(width) end
        if texture.SetHeight then texture:SetHeight(height) end
    end
    data.applyingGeometry = nil
end

local function ApplyIconBorderAppearance(self, data, target)
    local border = data and data.border
    local style = data and data.borderStyle
    if not border or not style then return false end
    local borderColor = data.configuredBorderColor
        or self:GetResolvedAppearanceColor(style, "border")
        or self:GetComponentBorderColor("icon", style)
        or { 1, 1, 1, 1 }
    if data.borderMode == "quality" then
        local quality
        if type(data.qualityProvider) == "function" then
            local ok, provided = pcall(data.qualityProvider, target)
            if ok then quality = provided end
        else
            quality = data.quality
        end
        local item = _G.C_Item
        if quality ~= nil and item and item.GetItemQualityColor then
            local red, green, blue = item.GetItemQualityColor(quality)
            if red then borderColor = { red, green, blue, 1 } end
        end
    end
    if (data.borderMode == "automatic" or data.borderMode == "quality")
        and type(data.borderColorProvider) == "function" then
        local ok, provided = pcall(data.borderColorProvider, target)
        if ok and type(provided) == "table" then borderColor = provided end
    end
    data.effectiveBorderColor = borderColor
    local shown = data.showBorder ~= false
        and (tonumber(data.borderSize) or 0) > 0
        and (not data.texture or not data.texture.IsShown
            or data.texture:IsShown())
    self:SetPixelBorderColor(border, unpack(borderColor))
    self:SetPixelBorderShown(border, false)
    HideIconShapeBorder(data)
    local definition = ICON_SHAPES[data.shape]
    if definition
        and EnsureIconShapeBorder(data, data.borderOwner, data.texture)
    then
        ApplyIconShapeBorderGeometry(
            self, data, data.texture, shown, borderColor)
    end
    return true
end

local function RefreshActiveIconPresentation(target)
    local data = NSkin:GetSkinData(target, ICON_COMPONENT_STATE, false)
    if not data or not data.active then return end
    if not CanModifyIconPresentation(target) or not CanModifyIconPresentation(data.texture)
        or not CanModifyIconPresentation(data.borderOwner) then return end
    ApplyIconGeometry(target)
    if data.shapeIconMaskAdded then ClearIconShapeMask(data) end
    ApplyIconNativeMask(data)
    ApplyIconTexCoords(target)
    ApplyIconCropMask(data, data.maskOwner or data.borderOwner, data.texture)
    if data.shape ~= "square" then
        if EnsureIconShapeMask(NSkin, data,
            data.maskOwner or data.borderOwner, data.texture) then
            data.activeShape = data.shape
        else
            DeactivateIconShape(data)
            data.shape = "square"
        end
    end
    ApplyIconBorderAppearance(NSkin, data, target)
end

local function EnsureIconTextureBaseline(self, texture, baselineID)
    local textureData = self:GetSkinData(texture, ICON_COMPONENT_STATE)
    if not textureData.baselineID then
        textureData.baselineID = baselineID
            or ("IconTexture:" .. tostring(texture))
        self:CaptureComponentBaseline(textureData.baselineID, texture, {
            size = true,
            points = true,
            texCoords = true,
        })
    end
    return textureData, self:GetComponentBaseline(textureData.baselineID)
end

local function SkinSingleIconPresentation(self, target, options, secondary)
    if not target or (target.IsForbidden and target:IsForbidden()) then
        return false
    end
    options = options or {}
    local texture = ResolveIconTexture(target, options)
    if not texture or not texture.SetTexCoord
        or not CanModifyIconPresentation(texture)
    then return false end

    local owner = options.borderOwner
        or (target.GetObjectType and target:GetObjectType() ~= "Texture"
            and target)
        or (texture.GetParent and texture:GetParent())
    local maskOwner = options.shapeMaskOwner or owner
    if not owner or not owner.CreateTexture
        or not CanModifyIconPresentation(owner)
        or not maskOwner or not maskOwner.CreateMaskTexture
        or not CanModifyIconPresentation(maskOwner)
    then return false end

    local data = self:GetSkinData(target, ICON_COMPONENT_STATE)
    local textureData = EnsureIconTextureBaseline(
        self, texture, options.baselineID)
    local borderKey = options.borderKey or (owner == target
        and ICON_BORDER_KEY
        or (ICON_BORDER_KEY .. ":" .. tostring(texture)))
    if options.reset == true then
        data.active = nil
        ClearIconCropMask(data)
        DeactivateIconShape(data)
        data.suppressNativeMask = nil
        self:RestoreComponentBaseline(textureData.baselineID, {
            size = true,
            points = true,
        })
        ApplyDeclaredIconMasks(texture, data.nativeMasks,
            data.allowMaskedTexCoords, function()
                self:RestoreComponentBaseline(textureData.baselineID, { texCoords = true })
            end)
        ApplyIconNativeMask(data)
        local oldBorder = data.border
            or self:GetPixelBorder(owner, borderKey)
        self:SetPixelBorderShown(oldBorder, false)
        for _, state in pairs(data.nativeDecorationStates
            or data.nativeBorderStates or {})
        do
            if state.active then RestoreIconNativeDecoration(state) end
        end
        data.interactionActive = nil
        for _, state in pairs(data.interactionRegionStates or {}) do
            if state.active then RestoreIconInteractionRegion(state) end
        end
        if data.interactionGlow then
            data.interactionGlow:Hide()
            if data.interactionGlowMasked
                and data.interactionGlow.RemoveMaskTexture
            then
                data.interactionGlow:RemoveMaskTexture(
                    data.interactionGlowMask)
                data.interactionGlowMasked = nil
            end
        end
        data.borderStyle = nil
        data.configuredBorderColor = nil
        data.borderMode = nil
        data.qualityProvider = nil
        data.quality = nil
        return true
    end

    local style = options.style or self:GetStyle("icon")
    if not style then return false end
    local shape = ResolveIconShape(style, options)

    -- Treat clipping and border as one shape presentation. Clear the old
    -- pair before either resource can be configured for a different shape.
    if data.shape ~= shape or (data.texture and data.texture ~= texture)
        or (data.shapeIconMaskOwner and data.shapeIconMaskOwner ~= maskOwner) then
        DeactivateIconShape(data)
    else
        ClearIconShapeMask(data)
    end

    if data.texture and data.texture ~= texture then
        ClearIconCropMask(data)
        data.suppressNativeMask = nil
        ApplyIconNativeMask(data)
        data.nativeMask = nil
    end
    if data.border and (data.borderOwner ~= owner
        or data.borderKey ~= borderKey or data.texture ~= texture)
    then
        self:SetPixelBorderShown(data.border, false)
    end
    data.active = true
    data.texture = texture
    data.maskOwner = maskOwner
    data.textureBaselineID = textureData.baselineID
    data.preserveTexCoords = options.preserveTexCoords == true
    data.nativeMasks = options.nativeMasks
    data.allowMaskedTexCoords = options.allowMaskedTexCoords == true
    data.preserveAtlasTexCoords = options.preserveAtlasTexCoords == true
    data.shape = shape
    if data.nativeMask ~= options.nativeMask then
        data.suppressNativeMask = nil
        ApplyIconNativeMask(data)
        data.nativeMask = options.nativeMask
    end
    data.suppressNativeMask = options.suppressNativeMask == true
    ApplyIconNativeMask(data)
    data.zoom = tonumber(options.zoom)
        or tonumber(style.zoom) or 0
    data.crop = tonumber(options.crop)
        or tonumber(style.crop) or 1
    data.crop = math.max(0.01, math.min(1, data.crop))
    data.borderCrop = tonumber(options.borderCrop)
        or tonumber(style.crop) or data.crop
    data.borderCrop = math.max(0.01, math.min(1, data.borderCrop))

    local size = tonumber(options.size) or tonumber(style.size)
    size = size and size > 0 and size or nil
    local width = tonumber(options.width) or size or tonumber(style.width)
    local height = tonumber(options.height) or size or tonumber(style.height)
    width = width and width > 0 and width or nil
    height = height and height > 0 and height or nil
    local baseline = self:GetComponentBaseline(textureData.baselineID)
    data.geometryOwned = width ~= nil or height ~= nil
    if data.geometryOwned then
        local points = baseline and baseline.points
        local constrainedByAnchors = points and #points ~= 1
        local presentationOwnerWidth = constrainedByAnchors
            and owner.GetWidth and owner:GetWidth()
        local presentationOwnerHeight = constrainedByAnchors
            and owner.GetHeight and owner:GetHeight()
        presentationOwnerWidth = presentationOwnerWidth
            and presentationOwnerWidth > 0 and presentationOwnerWidth or nil
        presentationOwnerHeight = presentationOwnerHeight
            and presentationOwnerHeight > 0 and presentationOwnerHeight or nil
        local finalWidth = width or presentationOwnerWidth
            or (baseline and baseline.width)
            or (texture.GetWidth and texture:GetWidth())
        local finalHeight = height or presentationOwnerHeight
            or (baseline and baseline.height)
            or (texture.GetHeight and texture:GetHeight())
        self:MarkComponentGeometryModified(
            textureData.baselineID, "size", true)
        if constrainedByAnchors then
            data.geometryPoint = { "CENTER", owner, "CENTER", 0, 0 }
            self:MarkComponentGeometryModified(
                textureData.baselineID, "points", true)
        else
            data.geometryPoint = nil
        end
        data.presentationWidth = finalWidth
        data.presentationHeight = finalHeight
        ApplyIconGeometry(target)
    elseif baseline and (baseline.modified.size or baseline.modified.points) then
        data.presentationWidth = nil
        data.presentationHeight = nil
        data.geometryPoint = nil
        self:RestoreComponentBaseline(textureData.baselineID, {
            size = true,
            points = true,
        })
    end

    if data.preserveTexCoords then
        local texCoordBaseline = self:GetComponentBaseline(
            textureData.baselineID)
        if texCoordBaseline and texCoordBaseline.modified.texCoords then
            self:RestoreComponentBaseline(textureData.baselineID, {
                texCoords = true,
            })
        end
    end
    ApplyIconTexCoords(target)
    ApplyIconCropMask(data, maskOwner, texture)
    if shape ~= "square" then
        if not EnsureIconShapeMask(self, data, maskOwner, texture) then
            DeactivateIconShape(data)
            data.shape = "square"
        else
            data.activeShape = shape
        end
    end
    ApplyIconNativeDecorations(data, target, texture,
        options.nativeDecorationRegions or options.nativeBorderRegions)
    if not data.nativeDecorationControlHooksInstalled
        and _G.hooksecurefunc
    then
        data.nativeDecorationControlHooksInstalled = true
        for _, method in ipairs({
            "SetNormalTexture", "SetNormalAtlas",
            "SetPushedTexture", "SetPushedAtlas",
        }) do
            if type(target[method]) == "function" then
                pcall(_G.hooksecurefunc, target, method, function()
                    local state = NSkin:GetSkinData(
                        target, ICON_COMPONENT_STATE, false)
                    if state and state.active then
                        ApplyIconNativeDecorations(state, target,
                            state.texture, state.nativeDecorationDeclaration)
                    end
                end)
            end
        end
    end
    if not secondary then
        local borderFrame = owner
        local borderAnchor = texture
        if options.showBorder ~= false and target == texture
            and texture.GetObjectType and texture:GetObjectType() == "Texture"
            and _G.CreateFrame
        then
            local overlay = data.borderOverlay
            if not overlay then
                overlay = _G.CreateFrame("Frame", nil, owner)
                overlay:EnableMouse(false)
                data.borderOverlay = overlay
            elseif overlay:GetParent() ~= owner then
                overlay:SetParent(owner)
            end
            overlay:ClearAllPoints()
            overlay:SetAllPoints(texture)
            local textureParent = texture.GetParent and texture:GetParent()
            local level = owner.GetFrameLevel and owner:GetFrameLevel() or 0
            if textureParent and textureParent.GetFrameLevel then
                level = math.max(level, textureParent:GetFrameLevel())
            end
            if overlay:GetFrameLevel() ~= level + 1 then
                overlay:SetFrameLevel(level + 1)
            end
            borderFrame = overlay
            borderAnchor = overlay
        end
        if data.border and (data.borderOwner ~= owner
            or data.borderFrame ~= borderFrame
            or data.borderKey ~= borderKey or data.texture ~= texture)
        then
            self:SetPixelBorderShown(data.border, false)
        end
        local border = self:GetPixelBorder(borderFrame, borderKey)
            or self:CreatePixelBorder(borderFrame, borderKey,
                tonumber(options.borderSize) or tonumber(style.borderSize) or 1,
                nil, options.outside == true, borderAnchor)
        if not border then return false end
        border.anchor = borderAnchor
        data.border = border
        data.borderOwner = owner
        data.borderFrame = borderFrame
        data.borderKey = borderKey
        local borderSize = tonumber(options.borderSize)
            or tonumber(style.borderSize) or 1
        self:SetPixelBorderSize(border, math.max(1, borderSize))
        self:SetPixelBorderPadding(border,
            tonumber(options.borderPadding) or tonumber(style.borderPadding) or 0)
        data.borderPadding = tonumber(options.borderPadding)
            or tonumber(style.borderPadding) or 0
        data.borderStyle = style
        data.configuredBorderColor = options.borderColor
        data.borderMode = string.lower(tostring(
            options.borderMode or style.borderMode or "custom"))
        data.qualityProvider = options.qualityProvider
        data.borderColorProvider = options.borderColorProvider
        data.quality = options.quality
        data.showBorder = options.showBorder
        data.borderSize = borderSize
        ApplyIconBorderAppearance(self, data, target)
    else
        -- Secondary presentations own clipping/geometry only, never a border.
        if data.border then self:SetPixelBorderShown(data.border, false) end
        HideIconShapeBorder(data)
        data.borderStyle = nil
        data.borderOwner = owner
    end

    ApplyIconInteraction(self, data, target, texture, options)

    if not data.contentMethodHooksInstalled and _G.hooksecurefunc then
        for _, method in ipairs({
            "SetItem", "SetReagent", "Clear", "Reset",
        }) do
            if type(target[method]) == "function" then
                pcall(_G.hooksecurefunc, target, method,
                    RefreshActiveIconPresentation)
            end
        end
        data.contentMethodHooksInstalled = true
    end

    local sizeWatchTarget
    if target.HookScript and target.HasScript
        and target:HasScript("OnSizeChanged")
    then
        sizeWatchTarget = target
    elseif owner.HookScript and owner.HasScript
        and owner:HasScript("OnSizeChanged")
    then
        sizeWatchTarget = owner
    end
    if not data.sizeHooked and sizeWatchTarget then
        sizeWatchTarget:HookScript("OnSizeChanged", function()
            RefreshActiveIconPresentation(target)
        end)
        if _G.hooksecurefunc
            and type(sizeWatchTarget.SetScale) == "function"
        then
            pcall(_G.hooksecurefunc, sizeWatchTarget, "SetScale", function()
                RefreshActiveIconPresentation(target)
            end)
        end
        data.sizeHooked = true
    end
    textureData.appearanceTargets = textureData.appearanceTargets
        or setmetatable({}, { __mode = "k" })
    textureData.appearanceTargets[target] = true
    if not textureData.appearanceHooked and _G.hooksecurefunc then
        local function RefreshTexturePresentation()
            for appearanceTarget in pairs(textureData.appearanceTargets) do
                local state = NSkin:GetSkinData(
                    appearanceTarget, ICON_COMPONENT_STATE, false)
                if state and state.texture == texture then
                    RefreshActiveIconPresentation(appearanceTarget)
                end
            end
        end
        for _, method in ipairs({
            "SetSize", "SetWidth", "SetHeight", "SetTexture", "SetAtlas",
            "SetTexCoord", "ClearAllPoints", "SetPoint", "SetAllPoints",
            "Show", "Hide", "SetShown",
        }) do
            if type(texture[method]) == "function" then
                pcall(_G.hooksecurefunc, texture, method,
                    RefreshTexturePresentation)
            end
        end
        textureData.appearanceHooked = true
    end
    if data.nativeMask and data.nativeMaskHooked ~= texture
        and _G.hooksecurefunc
        and type(texture.AddMaskTexture) == "function"
    then
        local hooked = pcall(_G.hooksecurefunc, texture,
            "AddMaskTexture", function()
            local state = NSkin:GetSkinData(
                target, ICON_COMPONENT_STATE, false)
            if state and state.active then ApplyIconNativeMask(state) end
        end)
        if hooked then data.nativeMaskHooked = texture end
    end
    return true
end

local function CopyIconPresentationOptions(source)
    local result = {}
    for key, value in pairs(source or {}) do result[key] = value end
    return result
end

local function ResolveMultiPresentationGeometry(self, target, options, presentation)
    local texture = presentation and presentation.texture
    if not CanModifyIconPresentation(texture) then return nil end
    local owner = options.borderOwner
        or (target.GetObjectType and target:GetObjectType() ~= "Texture"
            and target)
        or (texture.GetParent and texture:GetParent())
    if not owner then return nil end

    local _, baseline = EnsureIconTextureBaseline(
        self, texture, options.baselineID)
    local style = options.style or self:GetStyle("icon")
    if not style then return nil end
    local crop = tonumber(options.crop) or tonumber(style.crop) or 1
    crop = math.max(0.01, math.min(1, crop))
    local size = tonumber(options.size) or tonumber(style.size)
    size = size and size > 0 and size or nil
    local width = tonumber(options.width) or size or tonumber(style.width)
    local height = tonumber(options.height) or size or tonumber(style.height)
    width = width and width > 0 and width or nil
    height = height and height > 0 and height or nil
    local points = baseline and baseline.points
    local constrainedByAnchors = points and #points ~= 1
    local ownerWidth = constrainedByAnchors and owner.GetWidth and owner:GetWidth()
    local ownerHeight = constrainedByAnchors and owner.GetHeight and owner:GetHeight()
    ownerWidth = ownerWidth and ownerWidth > 0 and ownerWidth or nil
    ownerHeight = ownerHeight and ownerHeight > 0 and ownerHeight or nil
    local finalWidth = width or ownerWidth or (baseline and baseline.width)
        or (texture.GetWidth and texture:GetWidth())
    local finalHeight = height or ownerHeight or (baseline and baseline.height)
        or (texture.GetHeight and texture:GetHeight())
    if not finalWidth or finalWidth <= 0 or not finalHeight or finalHeight <= 0 then
        return nil
    end
    return {
        width = finalWidth,
        height = finalHeight,
        zoom = tonumber(options.zoom) or tonumber(style.zoom) or 0,
        crop = crop,
    }
end

local function RestoreMaskGeometry(self, state)
    for mask, baselineID in pairs(state.maskBaselines or {}) do
        if CanModifyIconPresentation(mask) then
            self:RestoreComponentBaseline(baselineID, { points = true, size = true })
        end
    end
end

local function UpdateMaskGeometry(self, state, texture, masks, reset)
    state.maskBaselines = state.maskBaselines or {}
    for _, mask in ipairs(masks or {}) do
        if CanModifyIconPresentation(mask) then
            local id = state.maskBaselines[mask]
            if not id then
                id = "IconPresentationMask:" .. tostring(mask)
                self:CaptureComponentBaseline(id, mask, { points = true, size = true })
                state.maskBaselines[mask] = id
            end
            if reset then
                self:RestoreComponentBaseline(id, { points = true, size = true })
            else
                self:MarkComponentGeometryModified(id, "points", true)
                self:MarkComponentGeometryModified(id, "size", true)
                mask:ClearAllPoints()
                mask:SetAllPoints(texture)
            end
        end
    end
end

-- One registered ICON, one style, one outer border. Each presentation uses
-- the canonical renderer and its own first-write texture baseline.
function NSkin:SkinIcon(target, options)
    options = options or {}
    local presentations = options.presentations
    if not CanModifyIconPresentation(target) then return false end
    if not presentations then
        local previous = self:GetSkinData(target, "iconPresentations", false)
        if previous and not previous.applying then
            previous.applying = true
            for _, child in pairs(previous.children or {}) do
                local reset = CopyIconPresentationOptions(child.options)
                reset.reset = true
                if CanModifyIconPresentation(child.target) then SkinSingleIconPresentation(self, child.target, reset) end
                RestoreMaskGeometry(self, child)
            end
            previous.children = {}
            if previous.divider then previous.divider:Hide() end
            if previous.leftIndicator then previous.leftIndicator:Hide() end
            if previous.rightIndicator then previous.rightIndicator:Hide() end
            if previous.leftIndicatorOutline then previous.leftIndicatorOutline:Hide() end
            if previous.rightIndicatorOutline then previous.rightIndicatorOutline:Hide() end
            if previous.corner then previous.corner:Hide() end
            previous.applying = nil
        end
        return SkinSingleIconPresentation(self, target, options)
    end
    local state = self:GetSkinData(target, "iconPresentations")
    if state.applying then return true end
    state.applying = true
    state.children = state.children or {}
    local logicalGeometry
    if not options.reset then
        for _, presentation in ipairs(presentations) do
            logicalGeometry = ResolveMultiPresentationGeometry(
                self, target, options, presentation)
            if logicalGeometry then break end
        end
    end
    local current, primaryTexture, primaryData = {}, nil, nil
    for index, presentation in ipairs(presentations) do
        local texture = presentation.texture
        if CanModifyIconPresentation(texture) then
            local childTarget = index == 1 and target or texture
            local config = CopyIconPresentationOptions(options)
            config.presentations = nil
            config.texture = texture
            config.nativeMasks = presentation.nativeMasks
            config.nativeMask = presentation.nativeMask
            config.suppressNativeMask = presentation.suppressNativeMask
            config.allowMaskedTexCoords = presentation.allowMaskedTexCoords == true
            config.baselineID = nil -- per-texture first-write baseline
            if logicalGeometry then
                config.width = logicalGeometry.width
                config.height = logicalGeometry.height
                config.zoom = logicalGeometry.zoom
                config.crop = logicalGeometry.crop
            end
            if index > 1 then
                config.showBorder = false
                config.nativeDecorationRegions, config.nativeBorderRegions = nil, nil
                config.getHovered, config.hoverRegion, config.hoverRegions = nil, nil, nil
                config.getSelected, config.selectedRegion = nil, nil
            end
            local child = state.children[texture] or {}
            state.children[texture], current[texture] = child, true
            child.target, child.options = childTarget, config
            if SkinSingleIconPresentation(self, childTarget, config, index > 1) then
                local data = self:GetSkinData(childTarget, "iconComponent", false)
                if index == 1 then primaryTexture, primaryData = texture, data end
                UpdateMaskGeometry(self, child, texture,
                    presentation.presentationMasks, options.reset == true)
            end
        end
    end
    for texture, child in pairs(state.children) do
        if not current[texture] then
            local reset = CopyIconPresentationOptions(child.options)
            reset.reset = true
            if CanModifyIconPresentation(child.target) then SkinSingleIconPresentation(self, child.target, reset) end
            RestoreMaskGeometry(self, child)
            state.children[texture] = nil
        end
    end
    local owner = options.borderOwner or target
    if primaryTexture and primaryData and CanModifyIconPresentation(owner) then
        local split = not options.reset and options.splitVisible
            and options.splitVisible(target) == true
        if options.splitDivider and not state.divider then
            state.divider = owner:CreateTexture(nil, "OVERLAY", nil, 5)
            self:ConfigureOwnedPixelTexture(state.divider)
        end
        if state.divider then
            local divider = state.divider
            divider:ClearAllPoints()
            divider:SetPoint("CENTER", primaryTexture, "CENTER")
            divider:SetSize(self:GetPhysicalPixelSize(primaryTexture), primaryTexture:GetHeight())
            divider:SetColorTexture(unpack(primaryData.effectiveBorderColor or { 1, 1, 1, 1 }))
            if state.dividerMask and divider.RemoveMaskTexture then
                divider:RemoveMaskTexture(state.dividerMask)
                state.dividerMask = nil
            end
            if primaryData.shapeIconMaskAdded then
                state.dividerMask = primaryData.shapeIconMask
                divider:AddMaskTexture(state.dividerMask)
            end
            divider:SetShown(split == true)
        end
        if options.splitIndicator and not state.leftIndicator then
            state.leftIndicator = owner:CreateTexture(nil, "OVERLAY", nil, 6)
            state.rightIndicator = owner:CreateTexture(nil, "OVERLAY", nil, 6)
            state.leftIndicatorOutline = owner:CreateTexture(nil, "OVERLAY", nil, 5)
            state.rightIndicatorOutline = owner:CreateTexture(nil, "OVERLAY", nil, 5)
        end
        if state.leftIndicator and state.rightIndicator then
            local color = options.splitIndicatorColor
            if type(options.splitIndicatorColorProvider) == "function" then
                local ok, provided = pcall(options.splitIndicatorColorProvider, target)
                if ok and type(provided) == "table" then color = provided end
            end
            color = color or primaryData.effectiveBorderColor or { 1, 1, 1, 1 }
            local pixel = self:GetPhysicalPixelSize(primaryTexture)
            local scale = math.max(0.01,
                tonumber(options.splitIndicatorSize) or 0.34)
            local size = self:SnapToPhysicalPixel(primaryTexture,
                math.max(8 * pixel, math.min(primaryTexture:GetSize()) * scale))
            local spacing = self:SnapToPhysicalPixel(primaryTexture,
                (tonumber(options.splitIndicatorSpacing) or 0) * pixel)
            for index, indicator in ipairs({ state.leftIndicator, state.rightIndicator }) do
                local outline = index == 1 and state.leftIndicatorOutline
                    or state.rightIndicatorOutline
                indicator:SetTexture(options.splitIndicator)
                indicator:ClearAllPoints()
                indicator:SetSize(size, size)
                indicator:SetVertexColor(unpack(color))
                outline:SetTexture(options.splitIndicator)
                outline:ClearAllPoints()
                outline:SetSize(size + 2 * pixel, size + 2 * pixel)
                outline:SetVertexColor(0, 0, 0, 1)
                outline:SetPoint("CENTER", indicator, "CENTER")
            end
            state.leftIndicator:SetPoint("CENTER", primaryTexture, "LEFT", -spacing, 0)
            local leftRotation = options.splitIndicatorLeftRotation or -math.pi / 2
            state.leftIndicator:SetRotation(leftRotation)
            state.leftIndicatorOutline:SetRotation(leftRotation)
            state.rightIndicator:SetPoint("CENTER", primaryTexture, "RIGHT", spacing, 0)
            local rightRotation = options.splitIndicatorRightRotation or math.pi / 2
            state.rightIndicator:SetRotation(rightRotation)
            state.rightIndicatorOutline:SetRotation(rightRotation)
            local indicatorVisible = split == true
            if type(options.splitIndicatorVisible) == "function" then
                indicatorVisible = options.splitIndicatorVisible(target) == true
            end
            local showIndicators = not options.reset
                and options.splitIndicator ~= nil and indicatorVisible
            state.leftIndicator:SetShown(showIndicators)
            state.rightIndicator:SetShown(showIndicators)
            state.leftIndicatorOutline:SetShown(showIndicators)
            state.rightIndicatorOutline:SetShown(showIndicators)
        end
        if options.cornerIndicator and not state.corner then
            state.corner = owner:CreateTexture(nil, "OVERLAY", nil, 6)
        end
        if state.corner then
            state.corner:SetTexture(options.cornerIndicator)
            state.corner:ClearAllPoints()
            state.corner:SetPoint("BOTTOMRIGHT", primaryTexture, "BOTTOMRIGHT", -2, 2)
            local size = math.max(8, primaryTexture:GetWidth() * 0.25)
            state.corner:SetSize(size, size)
            state.corner:SetShown(not options.reset and options.cornerIndicator ~= nil
                and (not options.cornerVisible or options.cornerVisible(target)))
        end
    end
    if options.reset then
        if state.divider then state.divider:Hide() end
        if state.leftIndicator then state.leftIndicator:Hide() end
        if state.rightIndicator then state.rightIndicator:Hide() end
        if state.leftIndicatorOutline then state.leftIndicatorOutline:Hide() end
        if state.rightIndicatorOutline then state.rightIndicatorOutline:Hide() end
        if state.corner then state.corner:Hide() end
        for _, child in pairs(state.children) do RestoreMaskGeometry(self, child) end
    end
    state.applying = nil
    return primaryTexture ~= nil
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
    local style = options.style or self:GetStyle("progressBar")
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
            self:SetOwnedTextureColor(background, unpack(backgroundColor))
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
    definition.refreshAppearance = definition.refreshAppearance or function(_, element)
        local targets = element.highlightRegions
        if type(targets) == "function" then targets = targets(element) end
        targets = type(targets) == "table" and targets or { element.target }
        local options = {}
        for key, value in pairs(element.skinOptions or {}) do options[key] = value end
        options.style = NSkin:GetAppearanceStyle(
            "progressBar", element.appearanceWindowID, element.id)
        options.backgroundColor = options.style.background
        options.borderColor = NSkin:GetAppearanceBorderColor(
            "progressBar", options.style, element.appearanceWindowID, element.id)
        local applied
        for i = 1, #targets do
            applied = NSkin:SkinProgressBar(targets[i], options) or applied
            NSkin:ResnapPixelBordersForTarget(targets[i])
        end
        return applied == true
    end
    definition.refreshLayout = definition.refreshLayout or function(owner, element)
        if not element.refreshAppearance(owner, element) then return false end
        NSkin:NotifySkinningElementBoundsChanged(element.id)
        return true
    end
    definition.pixelBorderTargets = definition.pixelBorderTargets
        or definition.highlightRegions
    return self:RegisterSimpleMovableElement(definition)
end
