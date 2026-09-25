local _, NSkin = ...
local SCOPE = "PlayerSpells.Talents"
local PREFIX = "SpellBook.Talents."
local families = {
    Active = { shape = "square", old = "Hero.ActiveNodes" },
    Passive = { shape = "circle", old = "Hero.PassiveNodes" },
    Choice = { shape = "octagon", old = "Hero.ChoiceNodes" },
}
local state = { nodes = setmetatable({}, { __mode = "k" }), trees = {} }
local RefreshAll, RefreshBackgrounds
local function Safe(target)
    return target and not (target.IsForbidden and target:IsForbidden())
        and not (target.IsProtected and target:IsProtected() and InCombatLockdown())
end
local function Compact(...)
    local result = {}
    for i = 1, select("#", ...) do
        local value = select(i, ...)
        if Safe(value) then result[#result + 1] = value end
    end
    return result
end

local function EntryFamily(entry)
    local entries = Enum.TraitNodeEntryType
    local kind = entry and entry.type
    if kind == entries.SpendSquare or kind == entries.SpendCapstoneSquare then return "Active" end
    if kind == entries.SpendCircle or kind == entries.SpendSmallCircle
        or kind == entries.SpendCapstoneCircle then return "Passive" end
    -- RedButton and ArmorSet have other live contracts; never guess.
end

local function Family(button)
    local info = button:GetNodeInfo()
    if not info then return end
    local nodes = Enum.TraitNodeType
    if info.type == nodes.Selection or info.type == nodes.SubTreeSelection then return "Choice" end
    return EntryFamily(button:GetEntryInfo())
end

local function RevealFamily(button)
    -- SetSelectionInfo assigns entryInfo before Blizzard adds the acquired
    -- choice button to selectionFrameArray. An uninitialized/recycled button
    -- has no semantic entry yet and must not affect the main icon families.
    local entry = button and button.entryInfo
    return type(entry) == "table" and EntryFamily(entry) or nil
end

local function Tree(button)
    local info = button:GetNodeInfo()
    if not info then return end
    if info.subTreeID then return "Hero" end
    local currencies = state.talents.treeCurrencyInfo
    if not currencies then return end
    for _, cost in ipairs(state.talents:GetNodeCost(info.ID) or {}) do
        if currencies[1] and cost.ID == currencies[1].traitCurrencyID then return "Class" end
        if currencies[2] and cost.ID == currencies[2].traitCurrencyID then return "Spec" end
    end
end

local colors = {
    selected = { 1, 0.82, 0, 1 }, available = { 0.2, 1, 0.2, 1 },
    error = { 1, 0.15, 0.15, 1 }, disabled = { 0.45, 0.45, 0.45, 1 },
    gated = { 0.18, 0.18, 0.18, 1 }, ghost = { 0.45, 0.45, 0.45, 0.35 },
}
local function BorderColor(button)
    local visual = TalentButtonUtil.BaseVisualState
    local current = button.visualState
    if current == visual.RefundInvalid or current == visual.DisplayError then return colors.error end
    if current == visual.Selectable then return colors.available end
    if current == visual.Normal or current == visual.Maxed then return colors.selected end
    return colors.disabled
end
local function PvPBorderColor(slot)
    if not slot.slotIndex then return colors.disabled end
    local info = C_SpecializationInfo.GetPvpTalentSlotInfo(slot.slotIndex)
    if not info or not info.enabled then return colors.disabled end
    if slot.IsPendingTalentRemoval and slot:IsPendingTalentRemoval() then
        return colors.error
    end
    local selected = slot.GetSelectedTalent and slot:GetSelectedTalent()
    if selected then
        return colors.error
    end
    return colors.available
end
local function PvPIndicatorColor(slot)
    if not slot.slotIndex then return colors.disabled end
    local info = C_SpecializationInfo.GetPvpTalentSlotInfo(slot.slotIndex)
    if not info or not info.enabled then return colors.disabled end
    if slot.IsPendingTalentRemoval and slot:IsPendingTalentRemoval() then
        return colors.error
    end
    return slot.GetSelectedTalent and slot:GetSelectedTalent()
        and colors.selected or colors.available
end
local function RefreshPvPPlusColor(slot)
    if not Safe(slot) or not Safe(slot.Texture) or not slot.slotIndex then return end
    local texture = slot.Texture
    local data = NSkin:GetSkinData(texture, "talentPvPPlus")
    if not data.originalColor then data.originalColor = { texture:GetVertexColor() } end
    local info = C_SpecializationInfo.GetPvpTalentSlotInfo(slot.slotIndex)
    local selected = slot.GetSelectedTalent and slot:GetSelectedTalent()
    if not NSkin:IsModuleEnabled("SpellBook") then
        if data.active then texture:SetVertexColor(unpack(data.originalColor)) end
        data.active = nil
    elseif not selected then
        texture:SetVertexColor(unpack(info and info.enabled
            and colors.available or colors.disabled))
        data.active = true
    else
        -- Blizzard's Update owns the selected talent artwork and its tint.
        data.active = nil
    end
end
local function ChoiceRevealBorderColor(button)
    local visual = TalentButtonUtil.BaseVisualState
    if button.visualState == visual.RefundInvalid
        or button.visualState == visual.DisplayError then return colors.error end
    if button.isCurrentSelection then return colors.selected end
    if button.IsChoiceAvailable and button:IsChoiceAvailable() then
        return colors.available
    end
    return colors.disabled
end
local function SplitVisible(button)
    return button.Icon2 and button.Icon2:IsShown()
end

-- Edge geometry and visibility belong entirely to Blizzard. These are the
-- semantic branches in TalentEdgeArrowMixin:UpdateState, not dependency logic.
local function ResolveTalentEdgeColor(edge)
    local startButton, endButton = edge:GetStartButton(), edge:GetEndButton()
    local visual = TalentButtonUtil.BaseVisualState
    local startState, endState = startButton:GetVisualState(), endButton:GetVisualState()
    if startState == visual.RefundInvalid
        or (endState == visual.RefundInvalid and startState == visual.Maxed)
        or startState == visual.DisplayError or endState == visual.DisplayError then
        return colors.error
    end
    if endState == visual.Gated or endState == visual.Locked then return colors.gated end
    if edge:GetEdgeInfo().isActive then return colors.selected end
    return colors.disabled
end

local function RestoreTalentEdgeAppearance(edge)
    if not Safe(edge) then return end
    local data = NSkin:GetSkinData(edge, "talentEdgeAppearance", false)
    if not data or not data.active then return end
    for region, native in pairs(data.regions) do
        if Safe(region) then
            if native.atlas then region:SetAtlas(native.atlas, false)
            else region:SetTexture(native.texture) end
            if native.coords then region:SetTexCoord(unpack(native.coords)) end
            if not native.line then
                if native.width and native.height then
                    region:SetSize(native.width, native.height)
                end
                if native.rotation ~= nil then
                    region:SetRotation(data.nativeRotations
                        and data.nativeRotations[region] or native.rotation)
                end
            end
            region:SetVertexColor(unpack(native.color))
        end
    end
    data.nativeRotations = nil
    data.active = nil
end

-- CalculateAngleBetween(end, start) points back toward the prerequisite.
-- Blizzard's atlas is authored in the opposite direction; the right-facing
-- play-button needs native rotation minus one quarter-turn to point at end.
local ARROW_ART_OFFSET = -math.pi / 2
local function CaptureTalentEdgeNativeRotation(edge)
    local data = NSkin:GetSkinData(edge, "talentEdgeAppearance", false)
    if not data then return end
    data.nativeRotations = data.nativeRotations or {}
    for _, key in ipairs({ "ArrowHead", "GhostArrowHead" }) do
        local region = edge[key]
        if Safe(region) and region.GetRotation then
            data.nativeRotations[region] = region:GetRotation()
        end
    end
end

local function RefreshTalentEdgeAppearance(edge)
    if not Safe(edge) then return end
    local startButton, endButton = edge:GetStartButton(), edge:GetEndButton()
    if not Safe(startButton) or not Safe(endButton) or not edge:GetEdgeInfo()
        or startButton:GetTalentFrame() ~= state.talents
        or not NSkin:IsModuleEnabled("SpellBook") then
        RestoreTalentEdgeAppearance(edge)
        return
    end
    local data = NSkin:GetSkinData(edge, "talentEdgeAppearance")
    data.regions = data.regions or {}
    data.nativeRotations = data.nativeRotations or {}
    local color = ResolveTalentEdgeColor(edge)
    local arrowScale = NSkin:GetTalentsEdgeArrowScale()
    for _, key in ipairs({ "Line", "GhostLine", "ArrowHead", "GhostArrowHead" }) do
        local region = edge[key]
        if Safe(region) then
            local line = key == "Line" or key == "GhostLine"
            -- Blizzard keeps line geometry and thickness. Capture only the
            -- native artwork so a neutral line can share the head's tint.
            if not data.regions[region]
                or region:GetAtlas() then
                local previous = data.regions[region]
                data.regions[region] = {
                    line = line, color = { region:GetVertexColor() },
                    texture = region:GetTexture(),
                    atlas = region:GetAtlas(),
                    coords = region.GetTexCoord
                        and { region:GetTexCoord() } or nil,
                    width = not line and ((previous and previous.width)
                        or region:GetWidth()) or nil,
                    height = not line and ((previous and previous.height)
                        or region:GetHeight()) or nil,
                    rotation = not line and (data.nativeRotations[region]
                        or (region.GetRotation and region:GetRotation())) or nil,
                }
            end
            local native = data.regions[region]
            if line then
                -- Blizzard continues to own endpoints, angle and thickness.
                region:SetTexture("Interface\\AddOns\\NSkin\\Media\\talent-arrow-line.tga")
            else
                if data.nativeRotations[region] == nil then
                    data.nativeRotations[region] = native.rotation
                end
                region:SetTexture("Interface\\AddOns\\NSkin\\Media\\play-button.png")
                region:SetTexCoord(0, 1, 0, 1)
                if native.width and native.width > 0
                    and native.height and native.height > 0 then
                    region:SetSize(native.width * arrowScale,
                        native.height * arrowScale)
                end
                if data.nativeRotations[region] ~= nil then
                    region:SetRotation(data.nativeRotations[region]
                        + ARROW_ART_OFFSET)
                end
            end
            local tint = (key == "GhostLine" or key == "GhostArrowHead") and colors.ghost or color
            region:SetVertexColor(unpack(tint))
        end
    end
    data.active = true
end

local function SkinTalentEdge(edge)
    if not Safe(edge) or not edge.Line or not edge.ArrowHead then return end
    local data = NSkin:GetSkinData(edge, "talentEdgeAppearance")
    if not data.hooked then
        data.hooked = true
        -- Post-hook the actual instance method: ClassTalentEdgeArrowMixin has
        -- already finished its subtree arrowhead suppression at this point.
        hooksecurefunc(edge, "UpdateState", RefreshTalentEdgeAppearance)
        if type(edge.UpdatePosition) == "function" then
            hooksecurefunc(edge, "UpdatePosition", function(updatedEdge)
                CaptureTalentEdgeNativeRotation(updatedEdge)
                RefreshTalentEdgeAppearance(updatedEdge)
            end)
        end
        edge:HookScript("OnHide", RestoreTalentEdgeAppearance)
        edge:HookScript("OnShow", RefreshTalentEdgeAppearance)
    end
end

local function Descriptor(button, family)
    local record = state.nodes[button]
    if record and record.family == family then
        if family == "Choice" then
            local arrowOptions = NSkin:GetTalentsChoiceArrowOptions()
            record.descriptor.splitIndicatorSize = arrowOptions.size
            record.descriptor.splitIndicatorSpacing = arrowOptions.spacing
        end
        return record.descriptor
    end
    if record and record.family then
        NSkin:ReleaseIconGroupChild(PREFIX .. "Icons." .. record.family, button)
    end
    local descriptor = {
        target = button, texture = button.Icon, borderOwner = button,
        defaultShape = families[family].shape, borderColorProvider = BorderColor,
        getHovered = function(target) return target:IsMouseOver() end,
        nativeDecorationRegions = Compact(button.Shadow, button.StateBorder,
            button.StateBorderHover, button.BorderSheen, button.SelectableGlow,
            button.Glow),
        presentations = {{ texture = button.Icon, nativeMask = button.IconMask,
            suppressNativeMask = true,
            nativeMasks = Compact(button.IconMask, button.IconSplitMask),
            allowMaskedTexCoords = true,
            presentationMasks = Compact(button.IconSplitMask) }},
    }
    if family == "Choice" and button.Icon2 then
        descriptor.presentations[2] = { texture = button.Icon2,
            nativeMask = button.Icon2Mask, suppressNativeMask = true,
            nativeMasks = Compact(button.Icon2Mask), allowMaskedTexCoords = true,
            presentationMasks = Compact(button.Icon2Mask) }
        descriptor.splitVisible, descriptor.splitDivider = SplitVisible, true
        descriptor.splitIndicator = "Interface\\AddOns\\NSkin\\Media\\play-button.png"
        descriptor.splitIndicatorVisible = function() return true end
        descriptor.splitIndicatorLeftRotation = math.pi
        descriptor.splitIndicatorRightRotation = 0
        local arrowOptions = NSkin:GetTalentsChoiceArrowOptions()
        descriptor.splitIndicatorSize = arrowOptions.size
        descriptor.splitIndicatorSpacing = arrowOptions.spacing
    end
    record = record or {}
    record.family, record.descriptor = family, descriptor
    state.nodes[button] = record
    return descriptor
end

local function RefreshNode(button)
    if state.refreshing or not Safe(button) or not button:GetNodeInfo() then return end
    if state.nodes[button] and state.nodes[button].released then return end
    local family = Family(button)
    if not family then return end
    local descriptor = Descriptor(button, family)
    descriptor.style = NSkin:GetAppearanceStyle("icon", SCOPE, PREFIX .. "Icons." .. family)
    descriptor.borderColor = NSkin:GetAppearanceBorderColor("icon", descriptor.style,
        SCOPE, PREFIX .. "Icons." .. family)
    NSkin:SkinIcon(button, descriptor)
end

local function RefreshNodeRankText(button)
    if not Safe(button) or not Safe(button.SpendText)
        or not button:GetNodeInfo()
        or (state.nodes[button] and state.nodes[button].released) then
        return
    end
    local rank = button.SpendText
    local stateData = NSkin:GetSkinData(button, "talentRankText")
    if not stateData.shadowColor and rank.GetShadowColor then
        stateData.shadowColor = { rank:GetShadowColor() }
        stateData.shadowOffset = rank.GetShadowOffset
            and { rank:GetShadowOffset() } or nil
    end
    stateData.shadows = stateData.shadows or {}
    local id = PREFIX .. "NodeRankText"
    if NSkin:IsModuleEnabled("SpellBook") then
        NSkin:SkinText(rank,
            NSkin:GetAppearanceStyle("text", SCOPE, id))
        if rank.SetShadowColor then rank:SetShadowColor(0, 0, 0, 0) end
        if rank.SetShadowOffset then rank:SetShadowOffset(0, 0) end
        for _, shadow in ipairs(button.spendTextShadows or {}) do
            if Safe(shadow) then
                if stateData.shadows[shadow] == nil then
                    stateData.shadows[shadow] = shadow:GetAlpha()
                end
                shadow:SetAlpha(0)
            end
        end
        stateData.active = true
    else
        NSkin:SkinText(rank, nil, { reset = true })
        if stateData.active then
            if stateData.shadowColor and stateData.shadowColor[1]
                and rank.SetShadowColor then
                rank:SetShadowColor(unpack(stateData.shadowColor))
            end
            if stateData.shadowOffset and stateData.shadowOffset[1]
                and rank.SetShadowOffset then
                rank:SetShadowOffset(unpack(stateData.shadowOffset))
            end
            for shadow, alpha in pairs(stateData.shadows) do
                if Safe(shadow) then shadow:SetAlpha(alpha) end
            end
            stateData.active = nil
        end
    end
end

local function ResetNodeRankText(button)
    if not Safe(button) or not Safe(button.SpendText) then return end
    local data = NSkin:GetSkinData(button, "talentRankText", false)
    NSkin:SkinText(button.SpendText, nil, { reset = true })
    if not data or not data.active then return end
    if data.shadowColor and data.shadowColor[1]
        and button.SpendText.SetShadowColor then
        button.SpendText:SetShadowColor(unpack(data.shadowColor))
    end
    if data.shadowOffset and data.shadowOffset[1]
        and button.SpendText.SetShadowOffset then
        button.SpendText:SetShadowOffset(unpack(data.shadowOffset))
    end
    for shadow, alpha in pairs(data.shadows or {}) do
        if Safe(shadow) then shadow:SetAlpha(alpha) end
    end
    data.active = nil
end

local function RefreshNodeRankTexts()
    if not state.talents then return end
    for button in state.talents:EnumerateAllTalentButtons() do
        if Safe(button) and button:GetNodeInfo() then
            RefreshNodeRankText(button)
        end
    end
    return true
end

local function RefreshChoiceReveal(button)
    if not Safe(button) or not button.Icon or not state.talents
        or button:GetParent() ~= state.talents.SelectionChoiceFrame then return end
    local family = RevealFamily(button)
    if not family then return end
    local id = PREFIX .. "Icons." .. family
    local descriptor = Descriptor(button, family)
    descriptor.borderColorProvider = ChoiceRevealBorderColor
    descriptor.style = NSkin:GetAppearanceStyle("icon", SCOPE, id)
    descriptor.borderColor = NSkin:GetAppearanceBorderColor("icon", descriptor.style,
        SCOPE, id)
    NSkin:SkinIcon(button, descriptor)
end

local function RefreshChoiceReveals()
    local selection = state.talents and state.talents.SelectionChoiceFrame
    if not selection then return end
    for _, button in ipairs(selection.selectionFrameArray or {}) do
        if Safe(button) and button.Icon then
            RefreshChoiceReveal(button)
            local record = state.nodes[button]
            if record and not record.hooked then
                record.hooked = true
                if type(button.UpdateVisualState) == "function" then
                    hooksecurefunc(button, "UpdateVisualState", RefreshChoiceReveal)
                end
                if type(button.ApplySize) == "function" then
                    hooksecurefunc(button, "ApplySize", RefreshChoiceReveal)
                end
            end
        end
    end
end

local function HookNode(button)
    local record = state.nodes[button]
    if not record.rankHooked and type(button.UpdateSpendText) == "function" then
        hooksecurefunc(button, "UpdateSpendText", RefreshNodeRankText)
        if Safe(button.SpendText)
            and type(button.SpendText.SetFontObject) == "function" then
            hooksecurefunc(button.SpendText, "SetFontObject", function()
                RefreshNodeRankText(button)
            end)
        end
        record.rankHooked = true
    end
    if record.hooked then return end
    record.hooked = true
    for _, method in ipairs({ "UpdateIconTexture", "UpdateStateBorder", "ApplySize" }) do
        if type(button[method]) == "function" then hooksecurefunc(button, method, RefreshNode) end
    end
end

local function Roots(tree)
    local roots = {}
    local display = tree == "Class" and state.talents.ClassCurrencyDisplay
        or state.talents.SpecCurrencyDisplay
    if Safe(display) then roots[#roots + 1] = display end
    for button in state.talents:EnumerateAllTalentButtons() do
        if Safe(button) and Tree(button) == tree then roots[#roots + 1] = button end
    end
    return roots
end

function NSkin:GetTalentsPageBackground()
    local options = self:GetModuleOptions("SpellBook", false)
    return options and options.talentsPageBackground or {}
end
function NSkin:GetTalentsChoiceArrowOptions()
    local options = self:GetModuleOptions("SpellBook", false)
    local saved = options and options.talentsChoiceArrows or {}
    return { size = tonumber(saved.size) or 0.34,
        spacing = tonumber(saved.spacing) or 0 }
end
function NSkin:SetTalentsChoiceArrowOptions(values)
    local options = self:GetModuleOptions("SpellBook", true)
    options.talentsChoiceArrows = values and {
        size = math.max(0.15, math.min(0.6, tonumber(values.size) or 0.34)),
        spacing = math.max(-12, math.min(16, tonumber(values.spacing) or 0)),
    } or nil
    if state.talents then
        self:RefreshIconGroup(PREFIX .. "Icons.Choice")
        self:RefreshIconGroup(PREFIX .. "PvPIcons")
    end
    return true
end
function NSkin:GetTalentsEdgeArrowScale()
    local options = self:GetModuleOptions("SpellBook", false)
    return tonumber(options and options.talentsEdgeArrowScale) or 0.5
end
function NSkin:SetTalentsEdgeArrowScale(value)
    local options = self:GetModuleOptions("SpellBook", true)
    options.talentsEdgeArrowScale = value and math.max(0.2,
        math.min(1, tonumber(value) or 0.5)) or nil
    if state.talents and state.talents.edgePool then
        for edge in state.talents.edgePool:EnumerateActive() do
            RefreshTalentEdgeAppearance(edge)
        end
    end
    return true
end
function NSkin:SetTalentsPageBackground(values)
    local options = self:GetModuleOptions("SpellBook", true)
    options.talentsPageBackground = values
    RefreshBackgrounds()
    return true
end

RefreshBackgrounds = function()
    local talents = state.talents
    if not Safe(talents) then return end
    NSkin:ApplyTextureBackground(talents, {
        id = "TalentsPage", source = talents.Background,
        regions = Compact(talents.OverlayBackgroundRight, talents.OverlayBackgroundMid,
            talents.BackgroundFlash),
    }, NSkin:GetTalentsPageBackground())
end

local function RegisterText(id, target, tree)
    if not Safe(target) then return end
    NSkin:RegisterTextElement({ id = PREFIX .. id, module = "SpellBook",
        appearanceWindowID = SCOPE, label = id, target = target, window = state.window,
        compositionParentID = PREFIX .. tree .. "Tree",
        isEditable = function() return state.talents:IsVisible() and target:IsVisible() end })
end

local function RegisterTrees()
    if not state.talents:IsVisible() then return end
    for _, tree in ipairs({ "Class", "Spec" }) do
        local id = PREFIX .. tree .. "Tree"
        local children = { PREFIX .. tree .. "Title", PREFIX .. tree .. "Points" }
        local element = NSkin:RegisterOffsetContainer({ id = id, module = "SpellBook",
            appearanceWindowID = SCOPE, label = tree == "Spec" and "Specialization Tree" or "Class Tree",
            window = state.window, layoutParent = state.talents, priority = 60,
            composition = { mode = "CONTAINER", movementStrategy = "OFFSET_ROOTS",
                roots = function() return Roots(tree) end, children = children },
            highlightRegions = function() return Roots(tree) end,
            treeKey = tree,
            isEditable = function() return state.talents:IsVisible() and #Roots(tree) > 1 end,
        })
        state.trees[tree] = element
        local display = tree == "Class" and state.talents.ClassCurrencyDisplay or state.talents.SpecCurrencyDisplay
        if display then
            RegisterText(tree .. "Title", display.CurrencyLabel, tree)
            RegisterText(tree .. "Points", display.CurrentAmountContainer and display.CurrentAmountContainer.CurrencyAmount, tree)
        end
    end
    local hero = state.talents.HeroTalentsContainer
    if Safe(hero) then
        state.trees.Hero = NSkin:RegisterSimpleMovableElement({ id = PREFIX .. "HeroTree",
            module = "SpellBook", appearanceWindowID = SCOPE, label = "Hero Tree", kind = "MOVABLE",
            target = hero, window = state.window, priority = 61, treeKey = "Hero",
            composition = { mode = "CONTAINER", movementOwner = hero,
                children = { PREFIX .. "HeroTitle", PREFIX .. "HeroPoints", PREFIX .. "HeroHeaderIcon" } },
            highlightRegions = function()
                return Compact(hero.HeroSpecButton, hero.HeroSpecLabel, hero.CurrencyFrame,
                    hero.ExpandedContainer, hero.CollapsedContainer, hero.PreviewContainer)
            end,
            isEditable = function() return state.talents:IsVisible() and hero:IsVisible() end,
        })
        RegisterText("HeroTitle", hero.HeroSpecLabel, "Hero")
        RegisterText("HeroPoints", hero.CurrencyFrame and hero.CurrencyFrame.Text, "Hero")
        local header = hero.HeroSpecButton
        if Safe(header) and Safe(header.Icon1) then
            NSkin:RegisterIcon({ id = PREFIX .. "HeroHeaderIcon", module = "SpellBook",
                appearanceWindowID = SCOPE, label = "Hero specialization icon", target = header,
                texture = header.Icon1, window = state.window, compositionParentID = PREFIX .. "HeroTree",
                defaultShape = "circle",
                presentations = {
                    { texture = header.Icon1,
                        nativeMasks = Compact(header.IconMask, header.Icon1SplitMask,
                            header.HeroClassIconSheenMask),
                        allowMaskedTexCoords = true,
                        presentationMasks = Compact(header.IconMask,
                            header.Icon1SplitMask, header.HeroClassIconSheenMask) },
                    { texture = header.Icon2,
                        nativeMasks = Compact(header.Icon2SplitMask),
                        allowMaskedTexCoords = true,
                        presentationMasks = Compact(header.Icon2SplitMask) },
                    { texture = header.Icon1Anim,
                        nativeMasks = Compact(header.IconMask, header.Icon1SplitMask),
                        allowMaskedTexCoords = true },
                },
                nativeDecorationRegions = Compact(header.Border, header.ChoiceBorder,
                    header.StateBorder,
                    header.HeroClassRingBorder, header.HeroClassRingBorderSheen,
                    header.ChoiceBackground, header.ChoiceBackground2),
                hoverRegions = Compact(header.BorderHover, header.ChoiceBorderHover,
                    header.StateBorderHover,
                    header.Icon1Hover, header.Icon2Hover),
                getHovered = function()
                    return header:IsMouseOver() and not header.isLocked
                        and not header:IsInspecting()
                end,
                isEditable = function() return state.talents:IsVisible() and header:IsVisible() end })
        end
    end
end

local function RefreshHeroPanels()
    local hero = state.talents and state.talents.HeroTalentsContainer
    if not Safe(hero) then return end
    local style = NSkin:GetAppearanceStyle("window", SCOPE, PREFIX .. "Window")
    if not style then return end
    local background = NSkin:GetResolvedAppearanceColor(style, "background")
    local border = NSkin:GetAppearanceBorderColor("window", style,
        SCOPE, PREFIX .. "Window")
    local content
    for _, definition in ipairs({
        { hero.PreviewContainer, "Preview", "Background" },
        { hero.ExpandedContainer, "Expanded", "Background" },
        { hero.CollapsedContainer, "Collapsed", "BackgroundTop",
            "BackgroundMiddle", "BackgroundBottom" },
    }) do
        local container, id = definition[1], definition[2]
        local source = container and container[definition[3]]
        if Safe(container) and Safe(source) then
            local regions = {}
            for index = 4, #definition do
                regions[#regions + 1] = container[definition[index]]
            end
            if id == "Expanded" then
                regions[#regions + 1] = container.HeroClassBackplateFullSheen
            end
            NSkin:ApplyTextureBackground(container, {
                id = "Hero" .. id, source = source, regions = Compact(unpack(regions)),
            }, { mode = "NONE" })
            if not container.NSkinHeroVisibilityHooked then
                container.NSkinHeroVisibilityHooked = true
                container:HookScript("OnShow", RefreshHeroPanels)
                container:HookScript("OnHide", RefreshHeroPanels)
            end
            if container:IsShown() then
                content = container.NodesContainer or container.BlankNodes
            end
        end
    end
    local panel = hero.NSkinHeroPanel
    if not Safe(content) then
        if panel then panel:Hide() end
        return
    end
    if not panel then
        panel = CreateFrame("Frame", nil, hero)
        panel:EnableMouse(false)
        hero.NSkinHeroPanel = panel
    end
    panel:SetFrameLevel(hero:GetFrameLevel() + 1)
    panel:ClearAllPoints()
    panel:SetPoint("TOP", content, "TOP", 0, 12)
    panel:SetPoint("LEFT", content, "LEFT", -12, 0)
    panel:SetPoint("RIGHT", content, "RIGHT", 12, 0)
    panel:SetPoint("BOTTOM", content, "BOTTOM", 0, -12)
    NSkin:CreateFlatBackground(panel, "NSkinHeroPanel", background, border)
    panel:Show()
end

RefreshAll = function()
    if not state.talents or state.refreshing or InCombatLockdown() then return end
    state.refreshing = true
    for button in state.talents:EnumerateAllTalentButtons() do
        if Safe(button) and button:GetNodeInfo() then
            local family = Family(button)
            if family then Descriptor(button, family); HookNode(button) end
        end
    end
    for family in pairs(families) do NSkin:RefreshIconGroup(PREFIX .. "Icons." .. family) end
    RefreshNodeRankTexts()
    RegisterTrees()
    RefreshHeroPanels()
    RefreshBackgrounds()
    state.refreshing = nil
end

function NSkin:RegisterPlayerSpellsTalents(window, talents)
    if not Safe(talents) or not talents.EnumerateAllTalentButtons then return false end
    state.window, state.talents = window, talents
    local rankID = PREFIX .. "NodeRankText"
    if not self:GetSkinningElement(rankID) then
        self:RegisterSkinningElement(rankID, {
            module = "SpellBook", appearanceWindowID = SCOPE,
            label = "Talent node rank text", kind = "TEXT",
            window = window, target = talents, draggable = false,
            appearanceStyles = { "text" }, appearanceTypeIDs = { "TEXT" },
            editorOptions = { { id = "shared.textAppearance", label = "Text",
                category = "CUSTOMIZE" } },
            highlightRegions = function()
                local regions = {}
                for button in talents:EnumerateAllTalentButtons() do
                    if Safe(button) and Safe(button.SpendText)
                        and button.SpendText:IsShown() then
                        regions[#regions + 1] = button.SpendText
                    end
                end
                return regions
            end,
            refreshAppearance = RefreshNodeRankTexts,
            refreshLayout = RefreshNodeRankTexts,
            isEditable = function()
                return talents:IsVisible()
            end,
        })
    end
    local moduleOptions = self:GetModuleOptions("SpellBook", true)
    if moduleOptions.talentBackgrounds then
        -- The checkpoint stored ambiguous per-tree page crops. Prefer the Spec
        -- setting, then Class, once; Hero customization is intentionally retired.
        if not moduleOptions.talentsPageBackground then
            for _, tree in ipairs({ "Spec", "Class" }) do
                local saved = moduleOptions.talentBackgrounds[tree]
                if saved and saved.mode and saved.mode ~= "DEFAULT" then
                    moduleOptions.talentsPageBackground = { mode = saved.mode, path = saved.path }
                    break
                end
            end
        end
        moduleOptions.talentBackgrounds = nil
    end
    for family, definition in pairs(families) do
        local id = PREFIX .. "Icons." .. family
        -- Preserve the real local override from the former Hero-only family.
        local profile = self:GetProfile()
        local overrides = profile.appearanceOverrides and profile.appearanceOverrides.elements
        if not moduleOptions.talentIconFamiliesMigrated and overrides
            and not overrides[id] and overrides[PREFIX .. definition.old] then
            overrides[id] = CopyTable(overrides[PREFIX .. definition.old])
        end
        if not self:GetSkinningElement(id) then
            self:RegisterIconGroup({ id = id, module = "SpellBook", appearanceWindowID = SCOPE,
                label = "Talent " .. family .. " Icons", target = talents, window = window,
                defaultShape = definition.shape, draggable = false,
                children = function()
                    local descriptors = {}
                    for button in talents:EnumerateAllTalentButtons() do
                        if Safe(button) and button:GetNodeInfo() and Family(button) == family then
                            descriptors[#descriptors + 1] = Descriptor(button, family)
                        end
                    end
                    local selection = talents.SelectionChoiceFrame
                    for _, button in ipairs(selection and selection.selectionFrameArray or {}) do
                        if Safe(button) and button.Icon and RevealFamily(button) == family then
                            local descriptor = Descriptor(button, family)
                            descriptor.borderColorProvider = ChoiceRevealBorderColor
                            descriptors[#descriptors + 1] = descriptor
                        end
                    end
                    return descriptors
                end,
                -- Families are edited in the Talents options page; the tree
                -- containers own Skinning Mode movement and combined highlights.
                isEditable = function() return false end,
            })
        end
    end
    moduleOptions.talentIconFamiliesMigrated = true
    if not state.hooked then
        state.hooked = true
        -- Arrow Init calls the base mixin directly before UpdateState. This
        -- observes new/reused edges without scanning the pool on every acquire.
        hooksecurefunc(TalentEdgeBaseMixin, "Init", function(edge, startButton)
            if Safe(startButton) and startButton:GetTalentFrame() == state.talents then
                SkinTalentEdge(edge)
            end
        end)
        for edge in talents.edgePool:EnumerateActive() do
            SkinTalentEdge(edge)
            if edge.Line and edge.ArrowHead then RefreshTalentEdgeAppearance(edge) end
        end
        hooksecurefunc(talents, "ReleaseEdge", function(_, edge)
            RestoreTalentEdgeAppearance(edge)
        end)
        local selection = talents.SelectionChoiceFrame
        if Safe(selection) then
            hooksecurefunc(selection, "SetSelectionOptions", RefreshChoiceReveals)
            hooksecurefunc(selection, "UpdateSelectionOptions", RefreshChoiceReveals)
            hooksecurefunc(selection, "UpdateVisualState", RefreshChoiceReveals)
        end
        hooksecurefunc(talents, "ReleaseTalentDisplayFrame", function(_, button)
            local record = state.nodes[button]
            if record then
                NSkin:ReleaseIconGroupChild(PREFIX .. "Icons." .. record.family, button)
                local reset = {}
                for key, value in pairs(record.descriptor) do reset[key] = value end
                reset.reset = true
                NSkin:SkinIcon(button, reset)
            end
            ResetNodeRankText(button)
        end)
        for _, method in ipairs({ "UpdateAllButtons", "LoadTalentTreeInternal" }) do
            if type(talents[method]) == "function" then hooksecurefunc(talents, method, RefreshAll) end
        end
        hooksecurefunc(talents, "RefreshCurrencyDisplay", RegisterTrees)
        hooksecurefunc(talents, "UpdateTalentButtonPosition", function(_, button)
            if not Safe(button) or not button:GetNodeInfo() then return end
            local family = Family(button)
            if family then
                Descriptor(button, family)
                state.nodes[button].released = nil
                HookNode(button)
            end
            local tree = Tree(button)
            for _, previous in ipairs({ "Class", "Spec" }) do
                if previous ~= tree then
                    NSkin:ReleaseOffsetContainerRoot(PREFIX .. previous .. "Tree", button, false)
                end
            end
            if tree == "Class" or tree == "Spec" then
                NSkin:ObserveOffsetContainerLayout(PREFIX .. tree .. "Tree", button)
            end
            RefreshNode(button)
            RefreshNodeRankText(button)
        end)
        talents:RegisterCallback(TalentFrameBaseMixin.Event.TalentButtonReleased, function(_, button)
            if not Safe(button) then return end
            local record = state.nodes[button]
            if record then
                record.released = true
                NSkin:ReleaseIconGroupChild(PREFIX .. "Icons." .. record.family, button)
                -- Direct lifecycle application may precede the first group refresh.
                local reset = {}
                for key, value in pairs(record.descriptor) do reset[key] = value end
                reset.reset = true
                NSkin:SkinIcon(button, reset)
            end
            ResetNodeRankText(button)
            for _, tree in ipairs({ "Class", "Spec" }) do
                NSkin:ReleaseOffsetContainerRoot(PREFIX .. tree .. "Tree", button, true)
            end
        end, state)
        hooksecurefunc(talents, "UpdateAllTalentButtonPositions", function()
            if InCombatLockdown() then return end
            for _, tree in ipairs({ "Class", "Spec" }) do
                NSkin:RefreshOffsetContainer(PREFIX .. tree .. "Tree")
            end
        end)
        hooksecurefunc(talents, "UpdateSpecBackground", function()
            local heroTree = state.trees.Hero
            if heroTree and not InCombatLockdown() then
                -- This native method authors exactly TOP -> ButtonsParent.
                -- A saved TOPLEFT must not survive alongside that native TOP.
                local hero = talents.HeroTalentsContainer
                for i = 1, hero:GetNumPoints() do
                    local point = { hero:GetPoint(i) }
                    if point[1] == "TOP" and point[2] == talents.ButtonsParent then
                        NSkin:ObserveMovableElementNativePoints(heroTree.id, { point })
                        hero:ClearAllPoints()
                        hero:SetPoint(unpack(point))
                        break
                    end
                end
                local placement = NSkin:GetSavedMovableElementPlacement(heroTree.id)
                if placement then heroTree.applyPlacement(heroTree, placement) end
            end
            RefreshBackgrounds()
        end)
        local hero = talents.HeroTalentsContainer
        if Safe(hero) and type(hero.UpdateHeroTalentUI) == "function" then
            hooksecurefunc(hero, "UpdateHeroTalentUI", RefreshAll)
        end
        talents:HookScript("OnShow", RefreshAll)
    end
    RefreshAll()
    return true
end

local function IsTalentControlVisible(talents, control)
    return talents and control and talents:IsVisible() and control:IsVisible()
end

local function ApplyTalentPresentationCleanup(talents)
    if not talents then return end

    -- Keep BottomBar as the functional anchor, but expose the NSkin window
    -- background underneath the Talent UI instead of Blizzard's bottom/black
    -- backing artwork.
    if talents.BottomBar then talents.BottomBar:SetAlpha(0) end
    if talents.BlackBG then talents.BlackBG:SetAlpha(0) end
    local warmode = talents.WarmodeButton
    if warmode and warmode.Ring then warmode.Ring:SetAlpha(0) end
end

function NSkin:RegisterTalentsControls(playerSpells)
    local talents = playerSpells and playerSpells.TalentsFrame
    if not Safe(talents) then return false end
    local loadSystem = talents.LoadSystem
    local loadoutDropdown = loadSystem and loadSystem.GetDropdown
        and loadSystem:GetDropdown() or (loadSystem and loadSystem.Dropdown)
    ApplyTalentPresentationCleanup(talents)
    local applied = NSkin:RegisterActionButton({
        id = PREFIX .. "ApplyButton",
        module = "SpellBook",
        appearanceWindowID = SCOPE,
        label = "Talent apply changes button",
        window = playerSpells,
        target = talents.ApplyButton,
        priority = 71,
        highlightRegions = { talents.ApplyButton },
        isEditable = function()
            return IsTalentControlVisible(talents, talents.ApplyButton)
        end,
    }) ~= nil
    applied = NSkin:RegisterSearchBox({
        id = PREFIX .. "SearchBox",
        module = "SpellBook",
        appearanceWindowID = SCOPE,
        label = "Talent search",
        window = playerSpells,
        target = talents.SearchBox,
        priority = 72,
        highlightRegions = { talents.SearchBox },
        isEditable = function()
            return IsTalentControlVisible(talents, talents.SearchBox)
        end,
    }) ~= nil or applied
    applied = NSkin:RegisterDropdown({
        id = PREFIX .. "LoadoutDropdown",
        module = "SpellBook",
        appearanceWindowID = SCOPE,
        label = "Talent loadout dropdown",
        window = playerSpells,
        target = loadoutDropdown,
        menus = { "MENU_CLASS_TALENT_PROFILE" },
        skinOptions = {
            preserveText = true,
            preserveMenuAnchor = true,
        },
        priority = 73,
        highlightRegions = { loadoutDropdown },
        isEditable = function()
            return IsTalentControlVisible(talents, loadoutDropdown)
        end,
    }) ~= nil or applied

    local pvpTray = talents.PvPTalentSlotTray
    local pvpLabel = pvpTray and pvpTray.Label
    applied = NSkin:RegisterTextElement({
        id = PREFIX .. "PvPLabel",
        module = "SpellBook",
        appearanceWindowID = SCOPE,
        label = "PvP talents label",
        window = playerSpells,
        target = pvpLabel,
        priority = 74,
        highlightRegions = { pvpLabel },
        isEditable = function()
            return IsTalentControlVisible(talents, pvpLabel)
        end,
    }) ~= nil or applied

    applied = NSkin:RegisterIconGroup({
        id = PREFIX .. "PvPIcons",
        module = "SpellBook",
        appearanceWindowID = SCOPE,
        label = "PvP talent icons",
        window = playerSpells,
        target = pvpTray,
        priority = 75,
        draggable = false,
        children = function()
            local children = {}
            for _, slot in ipairs(
                pvpTray and type(pvpTray.Slots) == "table"
                    and pvpTray.Slots or {})
            do
                if slot and slot.Texture then
                    children[#children + 1] = {
                        target = slot,
                        texture = slot.Texture,
                        borderOwner = slot,
                        defaultShape = "octagon",
                        borderColorProvider = PvPBorderColor,
                        getHovered = function(target) return target:IsMouseOver() end,
                        preserveTexCoords = true,
                        presentations = { { texture = slot.Texture,
                            nativeMask = slot.TextureMask,
                            suppressNativeMask = true } },
                        splitIndicator = "Interface\\AddOns\\NSkin\\Media\\play-button.png",
                        splitIndicatorVisible = function(target)
                            local info = target.slotIndex and
                                C_SpecializationInfo.GetPvpTalentSlotInfo(target.slotIndex)
                            return info and info.enabled and target.Texture:IsShown()
                        end,
                        splitIndicatorLeftRotation = math.pi,
                        splitIndicatorRightRotation = 0,
                        splitIndicatorColorProvider = PvPIndicatorColor,
                        splitIndicatorSize = NSkin:GetTalentsChoiceArrowOptions().size,
                        splitIndicatorSpacing = NSkin:GetTalentsChoiceArrowOptions().spacing,
                        nativeDecorationRegions = {
                            slot.Border,
                            slot.Shadow,
                        },
                    }
                end
            end
            return children
        end,
        highlightRegions = function()
            local regions = {}
            for _, slot in ipairs(
                pvpTray and type(pvpTray.Slots) == "table"
                    and pvpTray.Slots or {})
            do
                if slot and slot.Texture then
                    regions[#regions + 1] = slot.Texture
                end
            end
            return regions
        end,
        isEditable = function()
            return IsTalentControlVisible(talents, pvpTray)
        end,
    }) ~= nil or applied

    for _, slot in ipairs(pvpTray and pvpTray.Slots or {}) do
        if Safe(slot) and type(slot.Update) == "function" then
            local data = NSkin:GetSkinData(slot, "talentPvPSlot")
            if not data.hooked then
                data.hooked = true
                hooksecurefunc(slot, "Update", function()
                    NSkin:RefreshIconGroup(PREFIX .. "PvPIcons")
                    RefreshPvPPlusColor(slot)
                end)
            end
            RefreshPvPPlusColor(slot)
        end
    end

    applied = NSkin:RegisterPlayerSpellsTalents(
        playerSpells, talents) or applied

    applied = NSkin:RegisterDropdown({
        id = PREFIX .. "ResetButton",
        module = "SpellBook",
        appearanceWindowID = SCOPE,
        label = "Reset talents button",
        window = playerSpells,
        target = talents.ResetButton,
        menus = { "MENU_CLASS_TALENT_FRAME_RESET" },
        skinOptions = {
            showArrow = false,
            showBackground = false,
            showBorder = false,
            preserveMenuAnchor = true,
        },
        priority = 76,
        highlightRegions = { talents.ResetButton },
        isEditable = function()
            return IsTalentControlVisible(talents, talents.ResetButton)
        end,
    }) ~= nil or applied

    applied = NSkin:RegisterIcon({
        id = PREFIX .. "UndoButton",
        module = "SpellBook",
        appearanceWindowID = SCOPE,
        label = "Undo talent changes button",
        window = playerSpells,
        target = talents.UndoButton,
        texture = talents.UndoButton and talents.UndoButton.Icon,
        priority = 77,
        highlightRegions = { talents.UndoButton and talents.UndoButton.Icon },
        isEditable = function()
            return IsTalentControlVisible(talents, talents.UndoButton)
        end,
    }) ~= nil or applied

    return applied
end
