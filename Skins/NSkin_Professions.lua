local _, NSkin = ...

local ProfessionsSkin = NSkin:NewModule("Professions")
local RefreshCraftingAppearance

local IDs = {
    Scope = "Professions",
    Window = "Professions.Window",
    HeaderControls = "Professions.HeaderControls",
    ProgressBars = "Professions.ProgressBars",
    SpellIconPrefix = "Professions.SpellIcons.",
}

local PROFESSION_FRAME_NAMES = {
    "PrimaryProfession1",
    "PrimaryProfession2",
    "SecondaryProfession1",
    "SecondaryProfession2",
    "SecondaryProfession3",
}

local PROGRESS_BAR_STYLE = {
    stripArtwork = true,
    useAppearanceTexture = true,
    background = true,
}

local initialized = false
local applyPending = false
local lifecycleHooked = false
local progressBarsRegistered = false
local windowArtworkConcealed = false

NSkin:RegisterAppearanceScope(IDs.Scope, {
    label = "Professions",
})

local function IsVisible(frame)
    return frame and frame.IsVisible and frame:IsVisible() or false
end

local function IsForbidden(region)
    return region and region.IsForbidden and region:IsForbidden() or false
end

local function GetButtonTexture(button, getter, field)
    local texture = button and button[field]
    if texture then return texture end
    if button and type(button[getter]) == "function" then
        return button[getter](button)
    end
end

local function IsProfessionIconHovered(button)
    return button and button.IsMouseOver and button:IsMouseOver() or false
end

local function IsProfessionIconSelected(button)
    return button and button.GetChecked and button:GetChecked() == true
        or false
end

local function GetProfessionBars(visibleOnly)
    local bars = {}
    for i = 1, #PROFESSION_FRAME_NAMES do
        local profession = _G[PROFESSION_FRAME_NAMES[i]]
        local bar = profession and profession.statusBar
            or _G[PROFESSION_FRAME_NAMES[i] .. "StatusBar"]
        if bar and (not visibleOnly or IsVisible(bar)) then
            bars[#bars + 1] = bar
        end
    end
    return bars
end

local function QueueApply()
    if applyPending then return end
    applyPending = true
    C_Timer.After(0, function()
        applyPending = false
        ProfessionsSkin:Apply()
    end)
end

function ProfessionsSkin:ApplyWindowChrome(frame)
    if not frame then return false end

    if not windowArtworkConcealed then
        NSkin:HideTextureRegions(frame)
        windowArtworkConcealed = true
    end
    NSkin:ConcealWindowArtwork(frame.Inset)
    NSkin:SkinStandardWindowChrome({
        frame = frame,
        appearanceWindowID = IDs.Scope,
        elementID = IDs.Window,
        headerControlsID = IDs.HeaderControls,
        title = frame.TitleContainer and frame.TitleContainer.TitleText,
    })
    NSkin:RegisterSkinningElement(IDs.Window, {
        label = "Profession book window",
        kind = "WINDOW",
        module = "Professions",
        appearanceWindowID = IDs.Scope,
        window = frame,
        target = frame,
        priority = 0,
        draggable = false,
    })
    return true
end

function ProfessionsSkin:ApplyProgressBars(frame)
    local bars = GetProfessionBars(false)
    if not frame or #bars == 0 then return false end

    for i = 1, #bars do
        NSkin:SkinProgressBar(bars[i], PROGRESS_BAR_STYLE)
    end

    if not progressBarsRegistered then
        progressBarsRegistered = NSkin:RegisterProgressBarElement({
            id = IDs.ProgressBars,
            module = "Professions",
            appearanceWindowID = IDs.Scope,
            label = "Profession skill progress bars",
            window = frame,
            target = _G.ProfessionsContentFrame or frame,
            priority = 80,
            draggable = false,
            skinOptions = PROGRESS_BAR_STYLE,
            highlightRegions = function()
                return GetProfessionBars(true)
            end,
            isEditable = function()
                return IsVisible(frame) and #GetProfessionBars(true) > 0
            end,
        }) ~= nil
    end
    if progressBarsRegistered then
        NSkin:NotifySkinningElementBoundsChanged(IDs.ProgressBars)
    end
    return true
end

function ProfessionsSkin:ApplySpellIcons(frame)
    if not frame or (_G.InCombatLockdown and _G.InCombatLockdown()) then
        return false
    end

    local applied = false
    for i = 1, #PROFESSION_FRAME_NAMES do
        local frameName = PROFESSION_FRAME_NAMES[i]
        local profession = _G[frameName]
        for slot = 1, 2 do
            local button = profession and profession["SpellButton" .. slot]
            local texture = button and button.IconTexture
            if texture and not IsForbidden(button) and not IsForbidden(texture) then
                local element = NSkin:RegisterIcon({
                    id = IDs.SpellIconPrefix .. frameName
                        .. ".SpellButton" .. slot .. ".Icon",
                    module = "Professions",
                    appearanceWindowID = IDs.Scope,
                    label = "Profession spell icon",
                    window = frame,
                    target = button,
                    texture = texture,
                    hoverRegion = GetButtonTexture(
                        button, "GetHighlightTexture", "highlightTexture"),
                    selectedRegion = GetButtonTexture(
                        button, "GetCheckedTexture", "checkedTexture"),
                    getHovered = IsProfessionIconHovered,
                    getSelected = IsProfessionIconSelected,
                    priority = 70 + ((i - 1) * 2) + slot,
                    isEditable = function()
                        return IsVisible(frame) and IsVisible(button)
                            and not (_G.InCombatLockdown
                                and _G.InCombatLockdown())
                    end,
                })
                applied = element ~= nil or applied
            end
        end
    end
    return applied
end

function ProfessionsSkin:Apply()
    local frame = _G.ProfessionsBookFrame
    if not frame then return false end

    local applied = self:ApplyWindowChrome(frame)
    applied = self:ApplyProgressBars(frame) or applied
    applied = self:ApplySpellIcons(frame) or applied
    return applied
end

function ProfessionsSkin:Initialize()
    local frame = _G.ProfessionsBookFrame
    if not frame then return false end

    if not lifecycleHooked then
        if frame.HookScript then frame:HookScript("OnShow", QueueApply) end
        if _G.hooksecurefunc
            and type(_G.ProfessionsBookFrame_Update) == "function"
        then
            _G.hooksecurefunc("ProfessionsBookFrame_Update", QueueApply)
        end
        lifecycleHooked = true
    end

    initialized = true
    self:Apply()
    if frame:IsShown() then QueueApply() end
    return true
end

function ProfessionsSkin:RefreshAppearance()
    if initialized then self:Apply() end
    if RefreshCraftingAppearance then RefreshCraftingAppearance() end
end

NSkin:RegisterWindowSkin({
    module = "Professions",
    addon = "Blizzard_ProfessionsBook",
    apply = function() return ProfessionsSkin:Initialize() end,
})

do
local CraftingSkin = {}

local CraftingIDs = {
    RankBar = "Professions.Crafting.RankBar",
    QualityMaker = "Professions.Crafting.QualityMaker",
    EquipmentPrefix = "Professions.Crafting.Equipment.",
    Concentrate = "Professions.Crafting.Concentrate",
    ConcentrationIcon = "Professions.Crafting.Concentration.Icon",
    ConcentrationAmount = "Professions.Crafting.Concentration.Amount",
    Reagents = "Professions.Crafting.Reagents",
    OptionalReagents = "Professions.Crafting.OptionalReagents",
    FinishingReagents = "Professions.Crafting.FinishingReagents",
    StatLines = "Professions.Crafting.StatLines",
    RecipeSections = "Professions.Crafting.RecipeSections",
    RecipeRows = "Professions.Crafting.RecipeRows",
    Search = "Professions.Crafting.RecipeSearch",
    Filter = "Professions.Crafting.RecipeFilter",
    Tabs = "Professions.Crafting.Tabs",
    Create = "Professions.Crafting.Create",
    CreateAll = "Professions.Crafting.CreateAll",
    CreateCount = "Professions.Crafting.CreateCount",
    Decrement = "Professions.Crafting.CreateCount.Decrement",
    Increment = "Professions.Crafting.CreateCount.Increment",
    TextPrefix = "Professions.Crafting.Text.",
}

local craftingInitialized = false
local craftingLifecycleHooked = false
local registeredCraftingGroups = {}

local function AddRegion(regions, seen, region)
    if region and not seen[region] then
        seen[region] = true
        regions[#regions + 1] = region
    end
end

local function CompactRegions(...)
    local regions, seen = {}, {}
    for index = 1, select("#", ...) do
        AddRegion(regions, seen, select(index, ...))
    end
    return regions
end

local function IsCraftingVisible(frame, target)
    return IsVisible(frame) and IsVisible(target)
end

local function IsHovered(target)
    return target and target.IsMouseOver and target:IsMouseOver() or false
end

local function IsChecked(target)
    return target and target.GetChecked and target:GetChecked() == true or false
end

local function GetIconTexture(target)
    if not target then return nil end
    return target.Icon or target.icon or target.IconTexture
        or target.iconTexture
end

local function GetButtonStateTexture(button, method, field)
    if not button then return nil end
    if button[field] then return button[field] end
    if type(button[method]) == "function" then return button[method](button) end
end

local function GetEquipmentQuality(button)
    if not button or not button.slotID or not _G.GetInventoryItemQuality then
        return nil
    end
    return _G.GetInventoryItemQuality("player", button.slotID)
end

local function SuppressCraftingRegions(owner, key, regions)
    if not owner then return end
    local data = NSkin:GetSkinData(owner, "professionsCraftingDecorations")
    data[key] = data[key] or { states = {} }
    local group = data[key]
    local declared = {}
    for _, region in ipairs(regions or {}) do declared[region] = true end
    for region, state in pairs(group.states) do
        if state.active and not declared[region] then
            state.active = nil
            state.applying = true
            if region.SetAlpha then region:SetAlpha(state.alpha) end
            if state.shown ~= nil and region.SetShown then
                region:SetShown(state.shown)
            end
            state.applying = nil
        end
    end
    for region in pairs(declared) do
        local state = group.states[region]
        if not state then
            state = {
                alpha = region.GetAlpha and region:GetAlpha() or 1,
                shown = region.IsShown and region:IsShown() or nil,
            }
            group.states[region] = state
        end
        state.active = true
        local function Conceal()
            if state.active and not state.applying then
                state.applying = true
                if region.SetAlpha then region:SetAlpha(0) end
                state.applying = nil
            end
        end
        Conceal()
        if not state.hooked and _G.hooksecurefunc then
            for _, method in ipairs({ "SetAlpha", "SetShown", "Show" }) do
                if type(region[method]) == "function" then
                    pcall(_G.hooksecurefunc, region, method, Conceal)
                end
            end
            state.hooked = true
        end
    end
end

local function RegisterCraftingText(frame, id, label, target, priority)
    if not target then return nil end
    return NSkin:RegisterTextElement({
        id = id, module = "Professions",
        appearanceWindowID = IDs.Scope,
        label = label, window = frame, target = target,
        priority = priority, draggable = false,
        highlightRegions = { target },
        isEditable = function()
            return IsCraftingVisible(frame, target)
        end,
    })
end

local function RegisterCraftingIcon(frame, id, label, button, texture,
    priority, options)
    if not button or not texture or IsForbidden(button) or IsForbidden(texture) then
        return nil
    end
    options = options or {}
    return NSkin:RegisterIcon({
        id = id, module = "Professions",
        appearanceWindowID = IDs.Scope,
        label = label, window = frame, target = button, texture = texture,
        borderOwner = options.borderOwner,
        showBorder = options.showBorder,
        qualityProvider = options.qualityProvider,
        nativeDecorationRegions = options.nativeDecorationRegions,
        hoverRegion = options.hoverRegion,
        selectedRegion = options.selectedRegion,
        getHovered = options.getHovered,
        getSelected = options.getSelected,
        priority = priority,
        draggable = options.draggable,
        highlightRegions = options.highlightRegions,
        isEditable = function()
            return IsCraftingVisible(frame, button)
                and not (options.requiresOutOfCombat
                    and _G.InCombatLockdown
                    and _G.InCombatLockdown())
        end,
    })
end

local function GetPoolRegions(pool)
    local regions = {}
    if not pool or type(pool.EnumerateActive) ~= "function" then return regions end
    for region in pool:EnumerateActive() do regions[#regions + 1] = region end
    return regions
end

local function GetReagentSlots(form, reagentType)
    local slots = form and form.reagentSlots
        and form.reagentSlots[reagentType]
    return type(slots) == "table" and slots or {}
end

local function GetVisibleReagentSlots(form, reagentType)
    local visible = {}
    for _, slot in ipairs(GetReagentSlots(form, reagentType)) do
        if IsVisible(slot) then visible[#visible + 1] = slot end
    end
    return visible
end

local function GetReagentNativeDecorations(button)
    return CompactRegions(button and button.SlotBackground,
        button and button.CropFrame)
end

local function SkinReagentGroup(frame, form, reagentType, id)
    local style = NSkin:GetAppearanceStyle("icon", IDs.Scope, id)
    local border = NSkin:GetAppearanceBorderColor(
        "icon", style, IDs.Scope, id)
    local textStyle = NSkin:GetAppearanceStyle("text", IDs.Scope, id)
    local applied = false
    for _, slot in ipairs(GetReagentSlots(form, reagentType)) do
        local button = slot and slot.Button
        local texture = GetIconTexture(button)
        if button and texture then
            applied = NSkin:SkinIcon(button, {
                style = style, borderColor = border, texture = texture,
                nativeDecorationRegions = GetReagentNativeDecorations(button),
                getHovered = IsHovered,
            }) == true or applied
        end
        if slot and slot.Name then
            applied = NSkin:SkinText(slot.Name, textStyle) == true or applied
        end
    end
    return applied
end

local function RegisterReagentGroup(frame, form, reagentType, id, label)
    local parent = reagentType == Enum.CraftingReagentType.Basic
        and form.Reagents
        or reagentType == Enum.CraftingReagentType.Modifying
            and form.OptionalReagents
            or form.Details.CraftingChoicesContainer.FinishingReagentSlotContainer
    local function Refresh()
        return SkinReagentGroup(frame, form, reagentType, id)
    end
    if not registeredCraftingGroups[id] then
        registeredCraftingGroups[id] = NSkin:RegisterSkinningElement(id, {
            module = "Professions", appearanceWindowID = IDs.Scope,
            label = label, kind = "ICON", window = frame, target = parent,
            priority = 100, draggable = false,
            appearanceStyles = { "text" },
            appearanceTypeIDs = { "TEXT" },
            editorOptions = {
                { id = "shared.iconAppearance", label = "Icons",
                    presentation = "INLINE", category = "CUSTOMIZE" },
                { id = "shared.textAppearance", label = "Names",
                    category = "CUSTOMIZE" },
            },
            highlightRegions = function()
                return GetVisibleReagentSlots(form, reagentType)
            end,
            pixelBorderTargets = function()
                local targets = {}
                for _, slot in ipairs(GetVisibleReagentSlots(form, reagentType)) do
                    if slot.Button then targets[#targets + 1] = slot.Button end
                end
                return targets
            end,
            refreshAppearance = Refresh,
            refreshLayout = Refresh,
            isEditable = function()
                return IsVisible(frame)
                    and #GetVisibleReagentSlots(form, reagentType) > 0
            end,
        }) == true
    end
    Refresh()
    if registeredCraftingGroups[id] then
        NSkin:NotifySkinningElementBoundsChanged(id)
    end
    return registeredCraftingGroups[id]
end

local function GetStatLines(details)
    local lines, seen = {}, {}
    local container = details and details.StatLines
    for _, line in ipairs(container and container.StatLines or {}) do
        AddRegion(lines, seen, line)
    end
    for _, line in ipairs(GetPoolRegions(details and details.statLinePool)) do
        AddRegion(lines, seen, line)
    end
    return lines
end

local function GetVisibleStatLines(details)
    local visible = {}
    for _, line in ipairs(GetStatLines(details)) do
        if IsVisible(line) then visible[#visible + 1] = line end
    end
    return visible
end

local function ApplyStatLines(frame, details)
    local style = NSkin:GetAppearanceStyle(
        "text", IDs.Scope, CraftingIDs.StatLines)
    local applied = false
    for _, line in ipairs(GetStatLines(details)) do
        if line.LeftLabel then
            applied = NSkin:SkinText(line.LeftLabel, style) == true or applied
        end
        if line.RightLabel then
            applied = NSkin:SkinText(line.RightLabel, style) == true or applied
        end
    end
    return applied
end

local function RegisterStatLines(frame, details)
    local id = CraftingIDs.StatLines
    local function Refresh() return ApplyStatLines(frame, details) end
    if not registeredCraftingGroups[id] then
        registeredCraftingGroups[id] = NSkin:RegisterSkinningElement(id, {
            module = "Professions", appearanceWindowID = IDs.Scope,
            label = "Crafting detail stat lines", kind = "TEXT",
            window = frame, target = details.StatLines,
            priority = 120, draggable = false,
            highlightRegions = function() return GetVisibleStatLines(details) end,
            refreshAppearance = Refresh, refreshLayout = Refresh,
            isEditable = function()
                return IsVisible(frame) and #GetVisibleStatLines(details) > 0
            end,
        }) == true
    end
    Refresh()
    if registeredCraftingGroups[id] then
        NSkin:NotifySkinningElementBoundsChanged(id)
    end
end

local function IsRecipeCategory(row)
    return row and row.Label and row.CollapseIcon
        and row.LeftPiece and row.CenterPiece and row.RightPiece
end

local function IsRecipeRow(row)
    return row and row.Label and row.SelectedOverlay and row.HighlightOverlay
end

local function GetRecipeRows(page, predicate, visibleOnly)
    local rows = {}
    local scrollBox = page and page.RecipeList and page.RecipeList.ScrollBox
    if scrollBox and scrollBox.ForEachFrame then
        scrollBox:ForEachFrame(function(row)
            if predicate(row) and (not visibleOnly or IsVisible(row)) then
                rows[#rows + 1] = row
            end
        end)
    end
    return rows
end

local function IsRecipeCategoryExpanded(row)
    local node = row and row.GetElementData and row:GetElementData()
    return node and node.IsCollapsed and not node:IsCollapsed() or false
end

local function IsRecipeSelected(row)
    return row and row.SelectedOverlay and row.SelectedOverlay.IsShown
        and row.SelectedOverlay:IsShown() or false
end

local function ApplyRecipeSections(frame, page)
    local id = CraftingIDs.RecipeSections
    local style = NSkin:GetAppearanceStyle("sectionCard", IDs.Scope, id)
    local border = NSkin:GetAppearanceBorderColor(
        "sectionCard", style, IDs.Scope, id)
    local applied = false
    for _, row in ipairs(GetRecipeRows(page, IsRecipeCategory, false)) do
        applied = NSkin:SkinSectionCard(row, {
            style = style, border = border, textRegion = row.Label,
            preserveTextLayout = true, collapsible = true,
            getExpanded = IsRecipeCategoryExpanded,
            artworkRegions = CompactRegions(row.LeftPiece, row.CenterPiece,
                row.RightPiece, row.CollapseIcon, row.CollapseIconAlphaAdd),
        }) ~= nil or applied
    end
    return applied
end

local function ApplyRecipeRows(frame, page)
    local id = CraftingIDs.RecipeRows
    local style = NSkin:GetAppearanceStyle("row", IDs.Scope, id)
    local border = NSkin:GetAppearanceBorderColor("row", style, IDs.Scope, id)
    local textStyle = NSkin:GetAppearanceStyle("text", IDs.Scope, id)
    local applied = false
    for _, row in ipairs(GetRecipeRows(page, IsRecipeRow, false)) do
        applied = NSkin:SkinRow(row, {
            style = style, border = border,
            hoverRegion = row.HighlightOverlay,
            selectedRegion = row.SelectedOverlay,
            getHovered = IsHovered,
            getSelected = IsRecipeSelected,
        }) ~= nil or applied
        applied = NSkin:SkinText(row.Label, textStyle) == true or applied
        if row.Count then
            applied = NSkin:SkinText(row.Count, textStyle) == true or applied
        end
    end
    return applied
end

local function RegisterRecipeGroups(frame, page)
    for _, definition in ipairs({
        { CraftingIDs.RecipeSections, "Recipe section cards", "SECTION_CARD",
            IsRecipeCategory, ApplyRecipeSections, nil },
        { CraftingIDs.RecipeRows, "Recipe list rows", "ROW",
            IsRecipeRow, ApplyRecipeRows, "text" },
    }) do
        local id, label, kind, predicate, apply, extraStyle = unpack(definition)
        local function Refresh() return apply(frame, page) end
        if not registeredCraftingGroups[id] then
            local editorOptions
            if kind == "ROW" then
                editorOptions = {
                    { id = "shared.rowAppearance", label = "Rows",
                        category = "CUSTOMIZE" },
                    { id = "shared.textAppearance", label = "Recipe text",
                        category = "CUSTOMIZE" },
                }
            end
            registeredCraftingGroups[id] = NSkin:RegisterSkinningElement(id, {
                module = "Professions", appearanceWindowID = IDs.Scope,
                label = label, kind = kind, window = frame,
                target = page.RecipeList.ScrollBox,
                priority = kind == "SECTION_CARD" and 130 or 131,
                draggable = false,
                appearanceStyles = extraStyle and { extraStyle } or nil,
                appearanceTypeIDs = extraStyle and { "TEXT" } or nil,
                editorOptions = editorOptions,
                highlightRegions = function()
                    return GetRecipeRows(page, predicate, true)
                end,
                pixelBorderTargets = function()
                    return GetRecipeRows(page, predicate, true)
                end,
                refreshAppearance = Refresh, refreshLayout = Refresh,
                isEditable = function()
                    return IsVisible(frame)
                        and #GetRecipeRows(page, predicate, true) > 0
                end,
            }) == true
        end
        Refresh()
        if registeredCraftingGroups[id] then
            NSkin:NotifySkinningElementBoundsChanged(id)
        end
    end
end

local function ApplyHybridRankBar(frame, page)
    local bar = page and page.RankBar
    if not bar then return false end
    local progressStyle = NSkin:GetAppearanceStyle(
        "progressBar", IDs.Scope, CraftingIDs.RankBar)
    local progressBorder = NSkin:GetAppearanceBorderColor(
        "progressBar", progressStyle, IDs.Scope, CraftingIDs.RankBar)
    SuppressCraftingRegions(bar, "RankBarArtwork",
        CompactRegions(bar.Background, bar.Border))
    NSkin:CreateFlatBackground(bar, "NSkinProfessionsRankBarBackground",
        progressStyle.background, progressBorder)
    local pixelBorder = NSkin:GetPixelBorder(
        bar, "NSkinProfessionsRankBarBackgroundBorder")
    NSkin:SetPixelBorderColor(pixelBorder, unpack(progressBorder))
    NSkin:SetPixelBorderSize(pixelBorder, 1)
    NSkin:SetPixelBorderPadding(pixelBorder, 0)
    if progressStyle.useCustomColor and bar.Fill and bar.Fill.SetVertexColor then
        bar.Fill:SetVertexColor(unpack(progressStyle.color))
    end
    if progressStyle.useCustomTextColor and bar.Rank and bar.Rank.Text then
        NSkin:SetFontStringColor(bar.Rank.Text, unpack(progressStyle.text))
    end
    local dropdown = bar.ExpansionDropdownButton
    if dropdown then
        SuppressCraftingRegions(dropdown, "RankDropdownArtwork",
            CompactRegions(dropdown.Texture))
        NSkin:SkinDropdown(dropdown, {
            style = NSkin:GetAppearanceStyle(
                "button", IDs.Scope, CraftingIDs.RankBar),
        })
    end
    if not registeredCraftingGroups[CraftingIDs.RankBar] then
        local function Refresh() return ApplyHybridRankBar(frame, page) end
        registeredCraftingGroups[CraftingIDs.RankBar] =
            NSkin:RegisterSkinningElement(CraftingIDs.RankBar, {
                module = "Professions", appearanceWindowID = IDs.Scope,
                label = "Profession rank and expansion selector",
                kind = "PROGRESS_BAR", window = frame, target = bar,
                priority = 20, draggable = false,
                appearanceStyles = { "button" },
                appearanceTypeIDs = { "DROPDOWN" },
                highlightRegions = { bar },
                pixelBorderTargets = CompactRegions(bar, dropdown),
                refreshAppearance = Refresh, refreshLayout = Refresh,
                isEditable = function()
                    return IsCraftingVisible(frame, bar)
                end,
            }) == true
    end
    return true
end

local function GetDirectTextures(owner)
    local textures = {}
    if not owner or not owner.GetRegions then return textures end
    for _, region in ipairs({ owner:GetRegions() }) do
        if region.IsObjectType and region:IsObjectType("Texture") then
            textures[#textures + 1] = region
        end
    end
    return textures
end

local function ApplyQualityMaker(frame, form)
    local details = form and form.Details
    local quality = details and (details.QualityMaker or details.QualityMeter)
    if not quality then return false end
    if quality.IsObjectType and quality:IsObjectType("StatusBar") then
        return NSkin:RegisterProgressBarElement({
            id = CraftingIDs.QualityMaker, module = "Professions",
            appearanceWindowID = IDs.Scope, label = "Crafting quality",
            window = frame, target = quality, priority = 30,
            draggable = false,
            skinOptions = { background = true, useAppearanceTexture = true },
            highlightRegions = { quality },
            isEditable = function()
                return IsCraftingVisible(frame, quality)
            end,
        }) ~= nil
    end

    local center = quality.Center or quality
    local style = NSkin:GetAppearanceStyle(
        "progressBar", IDs.Scope, CraftingIDs.QualityMaker)
    local borderColor = NSkin:GetAppearanceBorderColor(
        "progressBar", style, IDs.Scope, CraftingIDs.QualityMaker)
    SuppressCraftingRegions(quality, "QualityMeterArtwork",
        CompactRegions(center and center.Background))
    SuppressCraftingRegions(quality.Border, "QualityMeterBorder",
        GetDirectTextures(quality.Border))
    NSkin:CreateFlatBackground(center, "NSkinProfessionsQualityBackground",
        style.background, borderColor)
    local border = NSkin:GetPixelBorder(
        center, "NSkinProfessionsQualityBackgroundBorder")
    NSkin:SetPixelBorderColor(border, unpack(borderColor))
    NSkin:SetPixelBorderSize(border, 1)
    NSkin:SetPixelBorderPadding(border, 0)
    local fill = center and center.Fill and center.Fill.Bar
    if style.useCustomColor and fill and fill.SetVertexColor then
        fill:SetVertexColor(unpack(style.color))
    end
    if not registeredCraftingGroups[CraftingIDs.QualityMaker] then
        local function Refresh() return ApplyQualityMaker(frame, form) end
        registeredCraftingGroups[CraftingIDs.QualityMaker] =
            NSkin:RegisterSkinningElement(CraftingIDs.QualityMaker, {
                module = "Professions", appearanceWindowID = IDs.Scope,
                label = "Crafting quality meter", kind = "PROGRESS_BAR",
                window = frame, target = quality, priority = 30,
                draggable = false, highlightRegions = { quality },
                pixelBorderTargets = { center },
                refreshAppearance = Refresh, refreshLayout = Refresh,
                isEditable = function()
                    return IsCraftingVisible(frame, quality)
                end,
            }) == true
    end
    return true
end

function CraftingSkin:ApplyEquipment(frame, page)
    if _G.InCombatLockdown and _G.InCombatLockdown() then return false end
    local applied = false
    for index, key in ipairs({
        "Prof0ToolSlot", "Prof1ToolSlot", "Prof0Gear0Slot",
        "Prof1Gear0Slot", "Prof0Gear1Slot", "Prof1Gear1Slot",
    }) do
        local button = page[key]
        local texture = GetIconTexture(button)
        if button and texture then
            local decorations = CompactRegions(button.SlotBackground,
                button.IconBorder,
                GetButtonStateTexture(button, "GetNormalTexture", "NormalTexture"))
            applied = RegisterCraftingIcon(frame,
                CraftingIDs.EquipmentPrefix .. key, "Profession equipment slot",
                button, texture, 40 + index, {
                    qualityProvider = GetEquipmentQuality,
                    nativeDecorationRegions = decorations,
                    hoverRegion = GetButtonStateTexture(
                        button, "GetHighlightTexture", "HighlightTexture"),
                    getHovered = IsHovered,
                    requiresOutOfCombat = true,
                }) ~= nil or applied
        end
    end
    return applied
end

function CraftingSkin:ApplyConcentration(frame, page, form)
    local details = form and form.Details
    local choices = details and details.CraftingChoicesContainer
    local container = choices and choices.ConcentrateContainer
    local button = container and container.ConcentrateToggleButton
    local texture = GetIconTexture(button)
    local applied = false
    if button and texture then
        applied = RegisterCraftingIcon(frame, CraftingIDs.Concentrate,
            "Concentration toggle", button, texture, 55, {
                nativeDecorationRegions = CompactRegions(
                    GetButtonStateTexture(button, "GetNormalTexture", "NormalTexture"),
                    GetButtonStateTexture(button, "GetPushedTexture", "PushedTexture")),
                hoverRegion = GetButtonStateTexture(
                    button, "GetHighlightTexture", "HighlightTexture"),
                selectedRegion = GetButtonStateTexture(
                    button, "GetCheckedTexture", "CheckedTexture"),
                getHovered = IsHovered, getSelected = IsChecked,
            }) ~= nil or applied
    end
    local display = page and page.ConcentrationDisplay
    if display and display.Icon then
        applied = RegisterCraftingIcon(frame, CraftingIDs.ConcentrationIcon,
            "Concentration display icon", display.Icon, display.Icon, 56, {
                showBorder = false, draggable = false,
                highlightRegions = { display.Icon },
            }) ~= nil or applied
    end
    applied = RegisterCraftingText(frame, CraftingIDs.ConcentrationAmount,
        "Concentration amount", display and display.Amount, 57) ~= nil or applied
    return applied
end

function CraftingSkin:ApplyStaticText(frame, form)
    local details = form and form.Details
    local choices = details and details.CraftingChoicesContainer
    local concentrate = choices and choices.ConcentrateContainer
    local finishing = choices and choices.FinishingReagentSlotContainer
    local applied = false
    for index, definition in ipairs({
        { "Output", "Recipe output", form and form.OutputText },
        { "RequiredTools", "Required tools", form and form.RequiredTools },
        { "Description", "Recipe description", form and form.Description },
        { "ReagentsLabel", "Reagents label", form and form.Reagents and form.Reagents.Label },
        { "OptionalReagentsLabel", "Optional reagents label",
            form and form.OptionalReagents and form.OptionalReagents.Label },
        { "DetailsLabel", "Crafting details label", details and details.Label },
        { "ConcentrateLabel", "Concentration label", concentrate and concentrate.Label },
        { "FinishingLabel", "Finishing reagents label", finishing and finishing.Label },
    }) do
        applied = RegisterCraftingText(frame,
            CraftingIDs.TextPrefix .. definition[1], definition[2],
            definition[3], 60 + index) ~= nil or applied
    end
    return applied
end

local function RegisterSpinnerButton(frame, id, label, button, glyph, priority)
    if not button then return nil end
    local function Refresh()
        local style = NSkin:GetAppearanceStyle("button", IDs.Scope, id)
        local border = NSkin:GetAppearanceBorderColor(
            "button", style, IDs.Scope, id)
        return NSkin:SkinWindowHeaderButton(button, { glyph = glyph }, {
            style = style, border = border,
        }) ~= nil
    end
    Refresh()
    if not registeredCraftingGroups[id] then
        registeredCraftingGroups[id] = NSkin:RegisterSkinningElement(id, {
            module = "Professions", appearanceWindowID = IDs.Scope,
            label = label, kind = "ACTION_BUTTON", window = frame,
            target = button, priority = priority, draggable = false,
            highlightRegions = { button }, pixelBorderTargets = { button },
            refreshAppearance = Refresh, refreshLayout = Refresh,
            isEditable = function()
                return IsCraftingVisible(frame, button)
            end,
        }) == true
    end
    return registeredCraftingGroups[id]
end

function CraftingSkin:ApplyControls(frame, page, form)
    local applied = false
    for index, definition in ipairs({
        { CraftingIDs.CreateAll, "Craft all", page.CreateAllButton or page.CraftAllButton },
        { CraftingIDs.Create, "Create", page.CreateButton },
    }) do
        local button = definition[3]
        if button then
            applied = NSkin:RegisterActionButton({
                id = definition[1], module = "Professions",
                appearanceWindowID = IDs.Scope, label = definition[2],
                window = frame, target = button, priority = 150 + index,
                isEditable = function()
                    return IsCraftingVisible(frame, button)
                end,
            }) ~= nil or applied
        end
    end
    local input = page.CreateMultipleInputBox
    if input then
        applied = RegisterSpinnerButton(frame, CraftingIDs.Decrement,
            "Decrease craft count", input.DecrementButton, "minimize", 153)
            ~= nil or applied
        applied = RegisterSpinnerButton(frame, CraftingIDs.Increment,
            "Increase craft count", input.IncrementButton, "maximize", 154)
            ~= nil or applied
        applied = NSkin:RegisterEditBox({
            id = CraftingIDs.CreateCount, module = "Professions",
            appearanceWindowID = IDs.Scope, label = "Craft count",
            window = frame, target = input, priority = 155,
            isEditable = function()
                return IsCraftingVisible(frame, input)
            end,
        }) ~= nil or applied
    end
    for index, checkbox in ipairs({
        form and form.TrackRecipeCheckbox,
        form and form.AllocateBestQualityCheckbox,
    }) do
        if checkbox then
            applied = NSkin:RegisterCheckbox({
                id = CraftingIDs.TextPrefix .. (index == 1
                    and "TrackRecipe" or "AllocateBestQuality"),
                module = "Professions", appearanceWindowID = IDs.Scope,
                label = index == 1 and "Track recipe"
                    or "Allocate best quality",
                window = frame, target = checkbox,
                text = checkbox.Text or checkbox.text,
                getChecked = IsChecked, priority = 155 + index,
                isEditable = function()
                    return IsCraftingVisible(frame, checkbox)
                end,
            }) ~= nil or applied
        end
    end
    local recipeList = page.RecipeList
    if recipeList and recipeList.SearchBox then
        applied = NSkin:RegisterSearchBox({
            id = CraftingIDs.Search, module = "Professions",
            appearanceWindowID = IDs.Scope, label = "Recipe search",
            window = frame, target = recipeList.SearchBox, priority = 160,
            isEditable = function()
                return IsCraftingVisible(frame, recipeList.SearchBox)
            end,
        }) ~= nil or applied
    end
    if recipeList and recipeList.FilterDropdown then
        applied = NSkin:RegisterDropdown({
            id = CraftingIDs.Filter, module = "Professions",
            appearanceWindowID = IDs.Scope, label = "Recipe filter",
            window = frame, target = recipeList.FilterDropdown, priority = 161,
            isEditable = function()
                return IsCraftingVisible(frame, recipeList.FilterDropdown)
            end,
        }) ~= nil or applied
    end
    return applied
end

function CraftingSkin:ApplyTabs(frame)
    local tabSystem = frame and frame.TabSystem
    if not tabSystem or type(tabSystem.tabs) ~= "table" then return false end
    return NSkin:RegisterTabGroup(CraftingIDs.Tabs, {
        module = "Professions", appearanceWindowID = IDs.Scope,
        label = "Profession tabs", window = frame, container = tabSystem,
        owner = frame, orientation = "HORIZONTAL", edge = "BOTTOM",
        priority = 170, draggable = false,
        isEditable = function()
            return IsVisible(frame) and IsVisible(tabSystem)
        end,
    }) == true
end

function CraftingSkin:HookLifecycle(frame, page, form)
    if craftingLifecycleHooked then return end
    if frame.HookScript then frame:HookScript("OnShow", function() CraftingSkin:Apply() end) end
    if page.HookScript then page:HookScript("OnShow", function() CraftingSkin:Apply() end) end
    if _G.hooksecurefunc then
        if type(form.Init) == "function" then
            pcall(_G.hooksecurefunc, form, "Init", function()
                RegisterReagentGroup(frame, form,
                    Enum.CraftingReagentType.Basic, CraftingIDs.Reagents,
                    "Basic reagent rows")
                RegisterReagentGroup(frame, form,
                    Enum.CraftingReagentType.Modifying,
                    CraftingIDs.OptionalReagents, "Optional reagent rows")
                RegisterReagentGroup(frame, form,
                    Enum.CraftingReagentType.Finishing,
                    CraftingIDs.FinishingReagents, "Finishing reagent slots")
                RegisterStatLines(frame, form.Details)
                ApplyQualityMaker(frame, form)
            end)
        end
        if form.Details and type(form.Details.SetStats) == "function" then
            pcall(_G.hooksecurefunc, form.Details, "SetStats", function()
                RegisterStatLines(frame, form.Details)
                ApplyQualityMaker(frame, form)
            end)
        end
        local scrollBox = page.RecipeList and page.RecipeList.ScrollBox
        if scrollBox and type(scrollBox.Update) == "function" then
            pcall(_G.hooksecurefunc, scrollBox, "Update", function()
                RegisterRecipeGroups(frame, page)
            end)
        end
    end
    craftingLifecycleHooked = true
end

function CraftingSkin:ApplyDynamic()
    local frame = _G.ProfessionsFrame
    local page = frame and frame.CraftingPage
    local form = page and page.SchematicForm
    if not frame or not page or not form then return false end
    RegisterReagentGroup(frame, form, Enum.CraftingReagentType.Basic,
        CraftingIDs.Reagents, "Basic reagent rows")
    RegisterReagentGroup(frame, form, Enum.CraftingReagentType.Modifying,
        CraftingIDs.OptionalReagents, "Optional reagent rows")
    RegisterReagentGroup(frame, form, Enum.CraftingReagentType.Finishing,
        CraftingIDs.FinishingReagents, "Finishing reagent slots")
    RegisterStatLines(frame, form.Details)
    RegisterRecipeGroups(frame, page)
    ApplyQualityMaker(frame, form)
    return true
end

function CraftingSkin:Apply()
    local frame = _G.ProfessionsFrame
    local page = frame and frame.CraftingPage
    local form = page and page.SchematicForm
    if not frame or not page or not form then return false end
    local applied = ApplyHybridRankBar(frame, page)
    applied = self:ApplyEquipment(frame, page) or applied
    applied = self:ApplyConcentration(frame, page, form) or applied
    applied = self:ApplyStaticText(frame, form) or applied
    applied = self:ApplyControls(frame, page, form) or applied
    applied = self:ApplyTabs(frame) or applied
    applied = self:ApplyDynamic() or applied
    return applied
end

function CraftingSkin:Initialize()
    local frame = _G.ProfessionsFrame
    local page = frame and frame.CraftingPage
    local form = page and page.SchematicForm
    if not frame or not page or not form then return false end
    self:HookLifecycle(frame, page, form)
    craftingInitialized = true
    return self:Apply()
end

RefreshCraftingAppearance = function()
    if craftingInitialized then CraftingSkin:Apply() end
end

NSkin:RegisterWindowSkin({
    key = "Professions.Crafting",
    module = "Professions",
    addon = "Blizzard_Professions",
    apply = function() return CraftingSkin:Initialize() end,
})
end
