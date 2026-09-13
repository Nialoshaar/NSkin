local _, NSkin = ...

local COMPONENT_STATE = "components"
local COLUMN_HEADER_STATE = "columnHeaderComponent"
local ROW_STATE = "rowComponent"
local COLUMN_HEADER_BACKGROUND = "NSkinColumnHeaderBackground"
local ROW_BACKGROUND = "NSkinRowBackground"

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

local function ApplyRowContentRegions(target, state, declared)
    local active = {}
    for _, region in ipairs(ResolveRowRegions(
        declared, target))
    do
        if region and region.GetFont and region.SetTextColor then
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

RefreshRowContentAppearance = function(target)
    local state = NSkin:GetSkinData(target, ROW_STATE, false)
    if not state or not state.active or state.applyingContent
        or not state.contentStyle
    then return end
    state.applyingContent = true
    for _, regionState in pairs(state.contentRegionStates or {}) do
        if regionState.active then
            regionState.applying = true
            NSkin:SkinText(regionState.region, state.contentStyle)
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
    local hovered = ResolveContentState(
        state.getHovered, state.hoverRegion, target)
    if state.selectedOverlay then state.selectedOverlay:SetShown(selected) end
    if state.hoverOverlay then state.hoverOverlay:SetShown(hovered) end
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
    state.contentStyle = options.contentStyle
    local visualRegion = ResolveContentValue(options.visualRegion, target)
    if not (visualRegion and visualRegion.GetObjectType) then
        visualRegion = target
    end

    if not state.originalHeight and target.GetHeight then
        state.originalHeight = target:GetHeight()
    end
    local height = tonumber(options.height)
        or tonumber(style.height)
    if height and height > 0 and target.SetHeight then
        target:SetHeight(height)
        state.heightModified = true
    elseif state.heightModified and state.originalHeight and target.SetHeight then
        target:SetHeight(state.originalHeight)
        state.heightModified = nil
    end

    local backgroundColor = self:GetResolvedAppearanceColor(
        style, "background")
    local borderColor = options.border
        or self:GetComponentBorderColor("row", style)
    local background = self:CreateFlatBackground(
        target, ROW_BACKGROUND, backgroundColor, borderColor)
    -- Table templates commonly place their cell FontStrings on BACKGROUND.
    -- Keep the owned surface below those Blizzard-owned contents.
    if background and background.SetDrawLayer then
        background:SetDrawLayer("BACKGROUND", -8)
    end
    AnchorContentSurface(background, visualRegion, 1)
    local border = self:GetPixelBorder(target, ROW_BACKGROUND .. "Border")
    state.background = background
    state.border = border
    if border then border.anchor = visualRegion end
    self:SetPixelBorderSize(border, style.borderSize or 1)
    self:SetPixelBorderPadding(border, style.borderPadding or 0)

    if not state.selectedOverlay then
        state.selectedOverlay = target:CreateTexture(nil, "ARTWORK", nil, 6)
        self:ConfigureOwnedPixelTexture(state.selectedOverlay)
    end
    if not state.hoverOverlay then
        state.hoverOverlay = target:CreateTexture(nil, "OVERLAY", nil, -1)
        self:ConfigureOwnedPixelTexture(state.hoverOverlay)
    end
    AnchorContentSurface(state.selectedOverlay, visualRegion, 1)
    AnchorContentSurface(state.hoverOverlay, visualRegion, 1)
    self:SetOwnedTextureColor(state.selectedOverlay, unpack(
        self:GetResolvedAppearanceColor(style, "selectedBackground")))
    self:SetOwnedTextureColor(
        state.hoverOverlay, 1, 1, 1, tonumber(style.hoverAlpha) or 0.10)

    local preserved = {
        [background] = true,
        [state.selectedOverlay] = true,
        [state.hoverOverlay] = true,
    }
    PreserveContentRegions(preserved, options.preserveTextures)
    ApplyRowNativeDecorations(target, state,
        options.nativeDecorationRegions or options.artworkRegions, preserved)
    ApplyRowStateRegions(target, state, {
        state.hoverRegion, state.selectedRegion,
    })
    ApplyRowContentRegions(target, state, options.contentRegions)
    if not state.hooked and target.HookScript then
        for _, script in ipairs({ "OnEnter", "OnLeave", "OnShow" }) do
            target:HookScript(script, RefreshRowPresentation)
        end
        state.hooked = true
    end
    if not state.methodHooksInstalled and _G.hooksecurefunc then
        for _, method in ipairs({
            "LockHighlight", "UnlockHighlight", "SetSelected",
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
            NSkin:SkinText(regionState.region, state.contentStyle)
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
    if state.hoverEventsManaged then
        hovered = state.pointerHovered == true
    else
        hovered = ResolveContentState(
            state.getHovered, state.hoverRegion, target)
    end
    if state.selectedOverlay then state.selectedOverlay:SetShown(selected) end
    if state.hoverOverlay then state.hoverOverlay:SetShown(hovered) end
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
    state.hoverEventsManaged = type(options.getHovered) == "function"
    state.pointerHovered = false
    state.contentStyle = options.contentStyle
    local visualRegion = ResolveContentValue(options.visualRegion, target)
    if not (visualRegion and visualRegion.GetObjectType) then
        visualRegion = target
    end

    local backgroundColor = self:GetResolvedAppearanceColor(style, "background")
    local borderColor = options.border
        or self:GetComponentBorderColor("sectionRow", style)
    local background = self:CreateFlatBackground(
        target, SECTION_ROW_BACKGROUND, backgroundColor, borderColor)
    if background and background.SetDrawLayer then
        background:SetDrawLayer("BACKGROUND", -8)
    end
    AnchorContentSurface(background, visualRegion, 1)
    local border = self:GetPixelBorder(
        target, SECTION_ROW_BACKGROUND .. "Border")
    state.background = background
    state.border = border
    if border then border.anchor = visualRegion end
    self:SetPixelBorderColor(border, unpack(borderColor))
    self:SetPixelBorderSize(border, style.borderSize or 1)
    self:SetPixelBorderPadding(border, style.borderPadding or 0)
    self:SetPixelBorderShown(border,
        style.showBorder == true and (tonumber(style.borderSize) or 0) > 0)

    if not state.selectedOverlay then
        state.selectedOverlay = target:CreateTexture(nil, "ARTWORK", nil, 6)
        self:ConfigureOwnedPixelTexture(state.selectedOverlay)
    end
    if not state.hoverOverlay then
        state.hoverOverlay = target:CreateTexture(nil, "OVERLAY", nil, -1)
        self:ConfigureOwnedPixelTexture(state.hoverOverlay)
    end
    AnchorContentSurface(state.selectedOverlay, visualRegion, 1)
    AnchorContentSurface(state.hoverOverlay, visualRegion, 1)
    self:SetOwnedTextureColor(state.selectedOverlay, unpack(
        self:GetResolvedAppearanceColor(style, "selectedBackground")))
    self:SetOwnedTextureColor(
        state.hoverOverlay, 1, 1, 1, tonumber(style.hoverAlpha) or 0.10)

    local preserved = {
        [background] = true,
        [state.selectedOverlay] = true,
        [state.hoverOverlay] = true,
    }
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
            if rowState and rowState.hoverEventsManaged then
                rowState.pointerHovered = true
            end
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
        local hovered = false
        if state.showHighlight then
            if state.interactionManaged then
                hovered = ResolveContentState(
                    state.getHovered, state.hoverRegion, target)
            else
                hovered = target.IsMouseOver
                    and target:IsMouseOver() == true or false
            end
        end
        state.glow:SetShown(hovered)
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
    state.showHighlight = style.showHighlight ~= false
    state.hoverRegion = ResolveSectionCardValue(options.hoverRegion, target)
    state.interactionManaged = options.getHovered ~= nil
        or options.hoverRegion ~= nil
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
    state.background = background
    state.border = border
    if border then border.anchor = visualRegion end
    self:SetPixelBorderColor(border, unpack(borderColor))
    self:SetPixelBorderSize(border, style.borderSize or 1)
    self:SetPixelBorderPadding(border, style.borderPadding or 0)
    self:SetPixelBorderShown(border,
        style.showBorder ~= false and (tonumber(style.borderSize) or 0) > 0)
    local glow = self:CreateFlatButtonGlow(target, style.hoverAlpha, true)
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
        applyTexCoords = function(texture, width, height, zoom)
            texture:SetTexCoord(NSkin:GetIconTexCoords(
                width, height, zoom))
        end,
    },
}

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
    active = active and type(target.CreateTexture) == "function"
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
    local glow = self:CreateFlatButtonGlow(target, alpha, true)
    if not glow then return end
    glow:ClearAllPoints()
    glow:SetPoint("TOPLEFT", texture, "TOPLEFT", 1, -1)
    glow:SetPoint("BOTTOMRIGHT", texture, "BOTTOMRIGHT", -1, 1)
    data.interactionGlow = glow
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

local function ApplyIconTexCoords(target)
    local data = NSkin:GetSkinData(target, ICON_COMPONENT_STATE, false)
    local texture = data and data.texture
    if not data or not data.active or data.applyingTexCoords
        or not texture or not texture.SetTexCoord
    then return end
    local width = texture.GetWidth and texture:GetWidth() or data.width
    local height = texture.GetHeight and texture:GetHeight() or data.height
    local shape = ICON_SHAPES[data.shape] or ICON_SHAPES.square
    data.applyingTexCoords = true
    shape.applyTexCoords(texture, width, height, data.zoom)
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
    self:SetPixelBorderColor(border, unpack(borderColor))
    self:SetPixelBorderShown(border,
        data.showBorder ~= false and (tonumber(data.borderSize) or 0) > 0)
    return true
end

local function RefreshActiveIconPresentation(target)
    local data = NSkin:GetSkinData(target, ICON_COMPONENT_STATE, false)
    if not data or not data.active then return end
    ApplyIconGeometry(target)
    ApplyIconTexCoords(target)
    ApplyIconBorderAppearance(NSkin, data, target)
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
        textureData.baselineID = options.baselineID
            or ("IconTexture:" .. tostring(texture))
        self:CaptureComponentBaseline(textureData.baselineID, texture, {
            size = true,
            points = true,
            texCoords = true,
        })
    end
    if options.reset == true then
        data.active = nil
        self:RestoreComponentBaseline(textureData.baselineID, {
            size = true,
            points = true,
            texCoords = true,
        })
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
        if data.interactionGlow then data.interactionGlow:Hide() end
        data.borderStyle = nil
        data.configuredBorderColor = nil
        data.borderMode = nil
        data.qualityProvider = nil
        data.quality = nil
        return true
    end

    local style = options.style or self:GetStyle("icon")
    if not style then return false end
    local shape = string.lower(tostring(
        options.shape or style.shape or "square"))
    if not ICON_SHAPES[shape] then shape = "square" end

    if data.border and (data.borderOwner ~= owner
        or data.borderKey ~= borderKey or data.texture ~= texture)
    then
        self:SetPixelBorderShown(data.border, false)
    end
    data.active = true
    data.texture = texture
    data.shape = shape
    data.zoom = tonumber(options.zoom)
        or tonumber(style.zoom) or 0
    data.crop = tonumber(options.crop)
        or tonumber(style.crop) or 1
    data.crop = math.max(0.01, math.min(1, data.crop))

    local width = tonumber(options.width) or tonumber(style.width)
    local height = tonumber(options.height) or tonumber(style.height)
    width = width and width > 0 and width or nil
    height = height and height > 0 and height or nil
    local baseline = self:GetComponentBaseline(textureData.baselineID)
    local cropped = data.crop < 1
    data.geometryOwned = width ~= nil or height ~= nil or cropped
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
        local finalHeight = cropped and finalWidth
            and self:SnapToPhysicalPixel(texture, finalWidth * data.crop)
            or height or presentationOwnerHeight
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

    self:MarkComponentGeometryModified(
        textureData.baselineID, "texCoords", true)
    ApplyIconTexCoords(target)
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
    ApplyIconInteraction(self, data, target, texture, options)

    local border = self:GetPixelBorder(owner, borderKey)
        or self:CreatePixelBorder(owner, borderKey,
            tonumber(options.borderSize) or tonumber(style.borderSize) or 1,
            nil, options.outside == true, texture)
    if not border then return false end
    border.anchor = texture
    data.border = border
    data.borderOwner = owner
    data.borderKey = borderKey
    local borderSize = tonumber(options.borderSize)
        or tonumber(style.borderSize) or 1
    self:SetPixelBorderSize(border, math.max(1, borderSize))
    self:SetPixelBorderPadding(border,
        tonumber(options.borderPadding) or tonumber(style.borderPadding) or 0)
    data.borderStyle = style
    data.configuredBorderColor = options.borderColor
    data.borderMode = string.lower(tostring(
        options.borderMode or style.borderMode or "custom"))
    data.qualityProvider = options.qualityProvider
    data.quality = options.quality
    data.showBorder = options.showBorder
    data.borderSize = borderSize
    ApplyIconBorderAppearance(self, data, target)

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

    local sizeWatchTarget = target.HookScript and target or owner
    if not data.sizeHooked and sizeWatchTarget and sizeWatchTarget.HookScript then
        sizeWatchTarget:HookScript("OnSizeChanged", function()
            ApplyIconTexCoords(target)
        end)
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
                    ApplyIconGeometry(appearanceTarget)
                    ApplyIconTexCoords(appearanceTarget)
                    ApplyIconBorderAppearance(
                        NSkin, state, appearanceTarget)
                end
            end
        end
        for _, method in ipairs({
            "SetSize", "SetWidth", "SetHeight", "SetTexture", "SetAtlas",
            "SetTexCoord", "ClearAllPoints", "SetPoint", "SetAllPoints",
        }) do
            if type(texture[method]) == "function" then
                pcall(_G.hooksecurefunc, texture, method,
                    RefreshTexturePresentation)
            end
        end
        textureData.appearanceHooked = true
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
