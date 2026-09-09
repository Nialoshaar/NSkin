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
    Window = "Professions.Crafting.Window",
    HeaderControls = "Professions.Crafting.HeaderControls",
    Equipment = "Professions.Crafting.Equipment",
    RankBar = "Professions.Crafting.RankBar",
    QualityMaker = "Professions.Crafting.QualityMaker",
    Concentrate = "Professions.Crafting.Concentrate",
    ConcentrationDisplay = "Professions.Crafting.ConcentrationDisplay",
    OutputIcon = "Professions.Crafting.OutputIcon",
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
    Details = "Professions.Crafting.Details",
    ReagentFlyout = "Professions.Crafting.ReagentFlyout",
    QualityDialog = "Professions.Crafting.QualityDialog",
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

local function NeverEditable()
    return false
end

local function GetIconTexture(target)
    if not target then return nil end
    return target.Icon or target.icon or target.IconTexture
        or target.iconTexture
end

local function GetConcentrateIconTexture(button)
    local icon = GetIconTexture(button)
    if icon and icon.IsObjectType and icon:IsObjectType("Texture") then
        return icon
    end
    -- Some client revisions wrap the template's Icon region in a keyed
    -- container. Keep this adapter-specific and only follow its known fields.
    local texture = icon and (icon.Texture or icon.Icon)
    if texture and texture.IsObjectType
        and texture:IsObjectType("Texture")
    then return texture end
end

local function GetButtonStateTexture(button, method, field)
    if not button then return nil end
    if button[field] then return button[field] end
    if type(button[method]) == "function" then return button[method](button) end
end

local function GetConcentrateDisplayedTexture(button)
    if button and button.IsEnabled and not button:IsEnabled() then
        local disabled = GetButtonStateTexture(
            button, "GetDisabledTexture", "DisabledTexture")
        if disabled and disabled.IsObjectType
            and disabled:IsObjectType("Texture")
        then return disabled end
    end
    return GetConcentrateIconTexture(button)
end

local function GetEquipmentQuality(button)
    if not button or not button.slotID or not _G.GetInventoryItemQuality then
        return nil
    end
    return _G.GetInventoryItemQuality("player", button.slotID)
end

local function GetResizeTargets(frame)
    local resize = frame and frame.MaximizeMinimize
    local targets = {}
    if resize and resize.MaximizeButton then
        targets[#targets + 1] = {
            target = resize.MaximizeButton, glyph = "maximize",
        }
    end
    if resize and resize.MinimizeButton then
        targets[#targets + 1] = {
            target = resize.MinimizeButton, glyph = "minimize",
        }
    end
    return targets
end

local function RefreshTypedElement(element)
    if element then NSkin:RefreshTypedElementAppearance(element) end
    return element
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

local function AddProfessionButtonDecorations(regions, seen, button)
    if not button then return end
    AddRegion(regions, seen, button.SlotBackground)
    AddRegion(regions, seen, button.IconBorder)
    AddRegion(regions, seen, button.IconOverlay)
    AddRegion(regions, seen, button.IconOverlay2)
end

local function GetProfessionItemButtonDecorations(button)
    local regions, seen = {}, {}
    AddProfessionButtonDecorations(regions, seen, button)
    return regions
end

local function GetProfessionButtonQuality(button)
    local reagent = button and button.GetReagent and button:GetReagent()
    if reagent and reagent.itemID and _G.C_Item
        and type(_G.C_Item.GetItemQualityByID) == "function"
    then
        return _G.C_Item.GetItemQualityByID(reagent.itemID)
    end
    if reagent and reagent.currencyID and _G.C_CurrencyInfo
        and type(_G.C_CurrencyInfo.GetCurrencyInfo) == "function"
    then
        local info = _G.C_CurrencyInfo.GetCurrencyInfo(reagent.currencyID)
        return info and info.quality
    end
    if button and type(button.GetItemInfo) == "function" then
        local ok, _, quality = pcall(button.GetItemInfo, button)
        if ok then return quality end
    end
end

local function GetProfessionItemButtonDescriptor(button)
    if not button then return nil end
    return {
        target = button,
        textureProvider = GetIconTexture,
        borderOwner = button,
        qualityProvider = GetProfessionButtonQuality,
        nativeDecorationRegions = function(currentButton)
            return GetProfessionItemButtonDecorations(currentButton)
        end,
        getHovered = IsHovered,
    }
end

local function GetQualityDialogArtwork(dialog)
    local regions = CompactRegions(dialog and dialog.NineSlice,
        dialog and dialog.Bg)
    if not dialog or not dialog.GetRegions then return regions end
    for _, region in ipairs({ dialog:GetRegions() }) do
        if region.IsObjectType and region:IsObjectType("Texture")
            and region.GetAtlas
            and region:GetAtlas() == "Professions-QualityWindow-Background"
        then
            regions[#regions + 1] = region
        end
    end
    return regions
end

local function RegisterCraftingPopup(frame, id, label, popup, refresh,
    appearanceStyles, appearanceTypeIDs)
    if not popup then return false end
    if not registeredCraftingGroups[id] then
        registeredCraftingGroups[id] = NSkin:RegisterSkinningElement(id, {
            module = "Professions", appearanceWindowID = IDs.Scope,
            label = label, kind = "WINDOW", window = frame, target = popup,
            priority = 175, draggable = false,
            appearanceStyles = appearanceStyles,
            appearanceTypeIDs = appearanceTypeIDs,
            highlightRegions = { popup },
            pixelBorderTargets = { popup },
            refreshAppearance = refresh,
            refreshLayout = refresh,
            isEditable = function()
                return IsVisible(frame) and IsVisible(popup)
            end,
        }) == true
    end
    refresh()
    if registeredCraftingGroups[id] then
        NSkin:NotifySkinningElementBoundsChanged(id)
    end
    return registeredCraftingGroups[id]
end

local function ApplyReagentFlyout(frame, flyout)
    if not flyout then return false end
    local id = CraftingIDs.ReagentFlyout
    local windowStyle = NSkin:GetAppearanceStyle("window", IDs.Scope, id)
    local buttonStyle = NSkin:GetAppearanceStyle("button", IDs.Scope, id)
    local buttonBorder = NSkin:GetAppearanceBorderColor(
        "button", buttonStyle, IDs.Scope, id)
    NSkin:SkinPopupSurface(flyout, {
        windowStyle = windowStyle,
        nativeDecorationRegions = CompactRegions(flyout.NineSlice),
        buttonStyle = buttonStyle,
        buttonBorder = buttonBorder,
        checkboxes = CompactRegions(flyout.HideUnownedCheckbox),
        scrollBar = flyout.ScrollBar,
        scrollBarStyle = NSkin:GetAppearanceStyle(
            "scrollBar", IDs.Scope, id),
        textStyle = NSkin:GetAppearanceStyle("text", IDs.Scope, id),
        textRegions = CompactRegions(flyout.Text,
            flyout.UndoItem and flyout.UndoItem.Text),
    })
    local icons = {}
    if flyout.ScrollBox and flyout.ScrollBox.ForEachFrame then
        flyout.ScrollBox:ForEachFrame(function(button)
            local descriptor = GetProfessionItemButtonDescriptor(button)
            if descriptor then icons[#icons + 1] = descriptor end
        end)
    end
    if flyout.UndoItem and flyout.UndoItem:IsShown() then
        icons[#icons + 1] = GetProfessionItemButtonDescriptor(flyout.UndoItem)
    end
    local applied = NSkin:SkinIconGroupChildren({
        id = id,
        appearanceWindowID = IDs.Scope,
        target = flyout,
        children = icons,
    })
    local data = NSkin:GetSkinData(flyout, "professionsFlyoutSkin")
    if not data.scrollBoxHooked and flyout.ScrollBox
        and type(flyout.ScrollBox.Update) == "function" and _G.hooksecurefunc
    then
        pcall(_G.hooksecurefunc, flyout.ScrollBox, "Update", function()
            ApplyReagentFlyout(frame, flyout)
        end)
        data.scrollBoxHooked = true
    end
    return applied or true
end

local function RegisterReagentFlyout(frame, flyout)
    return RegisterCraftingPopup(frame, CraftingIDs.ReagentFlyout,
        "Reagent selection popup", flyout,
        function() return ApplyReagentFlyout(frame, flyout) end,
        { "button", "icon", "text", "scrollBar" },
        { "ACTION_BUTTON", "ICON", "TEXT", "SCROLLBAR" })
end

local function ApplyQualityDialog(frame, dialog)
    if not dialog then return false end
    local id = CraftingIDs.QualityDialog
    local windowStyle = NSkin:GetAppearanceStyle("window", IDs.Scope, id)
    local buttonStyle = NSkin:GetAppearanceStyle("button", IDs.Scope, id)
    local buttonBorder = NSkin:GetAppearanceBorderColor(
        "button", buttonStyle, IDs.Scope, id)
    local editBoxStyle = NSkin:GetAppearanceStyle("editBox", IDs.Scope, id)
    local editBoxBorder = NSkin:GetAppearanceBorderColor(
        "editBox", editBoxStyle, IDs.Scope, id)
    local editBoxes = {}
    local icons = {}
    for _, container in ipairs({
        dialog.Container1, dialog.Container2, dialog.Container3,
    }) do
        if container then
            local descriptor = GetProfessionItemButtonDescriptor(
                container.Button)
            if descriptor then icons[#icons + 1] = descriptor end
            if container.EditBox then editBoxes[#editBoxes + 1] = container.EditBox end
        end
    end
    local applied = NSkin:SkinPopupSurface(dialog, {
        windowStyle = windowStyle,
        nativeDecorationRegions = GetQualityDialogArtwork(dialog),
        title = dialog.TitleContainer and dialog.TitleContainer.TitleText,
        closeButton = dialog.ClosePanelButton,
        actionButtons = CompactRegions(dialog.AcceptButton, dialog.CancelButton),
        editBoxes = editBoxes,
        buttonStyle = buttonStyle,
        buttonBorder = buttonBorder,
        editBoxStyle = editBoxStyle,
        editBoxBorder = editBoxBorder,
        textStyle = NSkin:GetAppearanceStyle("text", IDs.Scope, id),
    })
    applied = NSkin:SkinIconGroupChildren({
        id = id,
        appearanceWindowID = IDs.Scope,
        target = dialog,
        children = icons,
    }) or applied
    return applied
end

local function RegisterQualityDialog(frame, dialog)
    return RegisterCraftingPopup(frame, CraftingIDs.QualityDialog,
        "Reagent quality popup", dialog,
        function() return ApplyQualityDialog(frame, dialog) end,
        { "button", "icon", "editBox", "text" },
        { "ACTION_BUTTON", "ICON", "EDIT_BOX", "TEXT" })
end

local function ApplyOutputIcon(frame, form)
    local button = form and form.OutputIcon
    local texture = button and button.Icon
    if not button or not texture then return false end
    local element = NSkin:RegisterIcon({
        id = CraftingIDs.OutputIcon,
        module = "Professions",
        appearanceWindowID = IDs.Scope,
        label = "Recipe output icon",
        window = frame,
        target = button,
        texture = texture,
        borderOwner = button,
        nativeDecorationRegions = CompactRegions(button.IconBorder),
        hoverRegion = GetButtonStateTexture(
            button, "GetHighlightTexture", "HighlightTexture"),
        getHovered = IsHovered,
        priority = 58,
        draggable = false,
        isEditable = function()
            return IsCraftingVisible(frame, button)
        end,
    })
    RefreshTypedElement(element)
    return element ~= nil
end

local function RegisterCraftingText(frame, id, label, target, priority,
    appearanceOnly)
    if not target then return nil end
    return NSkin:RegisterTextElement({
        id = id, module = "Professions",
        appearanceWindowID = IDs.Scope,
        label = label, window = frame, target = target,
        priority = priority, draggable = false,
        highlightRegions = { target },
        isEditable = appearanceOnly and NeverEditable or function()
            return IsCraftingVisible(frame, target)
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

local function GetReagentIconSlots(form, reagentType)
    local slots, seen = {}, {}
    for _, slot in ipairs(GetReagentSlots(form, reagentType)) do
        AddRegion(slots, seen, slot)
    end
    -- Enchant recipes create this dedicated slot outside reagentSlots and
    -- present it in the OptionalReagents container.
    local enchantSlot = form and form.enchantSlot
    if reagentType == Enum.CraftingReagentType.Modifying and enchantSlot
        and (not enchantSlot.IsShown or enchantSlot:IsShown())
    then
        AddRegion(slots, seen, enchantSlot)
    end
    return slots
end

local function GetVisibleReagentIconSlots(form, reagentType)
    local visible = {}
    for _, slot in ipairs(GetReagentIconSlots(form, reagentType)) do
        if IsVisible(slot) then visible[#visible + 1] = slot end
    end
    return visible
end

local function GetReagentNativeDecorations(button)
    if not button then return {} end
    local decorations, seen = {}, {}
    AddProfessionButtonDecorations(decorations, seen, button)
    AddRegion(decorations, seen, button.CropFrame)
    -- Modifying-required slots use their normal/pushed textures as the
    -- functional large green plus. Other slots use those textures only for
    -- the native quick-slot frame, which NSkin replaces.
    if not button.showLargeAddIcon then
        AddRegion(decorations, seen, GetButtonStateTexture(
            button, "GetNormalTexture", "NormalTexture"))
        AddRegion(decorations, seen, GetButtonStateTexture(
            button, "GetPushedTexture", "PushedTexture"))
    end
    return decorations
end

local function GetReagentIconDescriptors(form, reagentType)
    local descriptors = {}
    for _, slot in ipairs(GetReagentIconSlots(form, reagentType)) do
        local button = slot and slot.Button
        if button then
            descriptors[#descriptors + 1] = {
                target = button,
                textureProvider = GetIconTexture,
                borderOwner = button,
                qualityProvider = GetProfessionButtonQuality,
                nativeDecorationRegions = function(currentButton)
                    return GetReagentNativeDecorations(currentButton)
                end,
                hoverRegions = function(currentButton)
                    local overlay = currentButton and currentButton.InputOverlay
                    return CompactRegions(
                        currentButton and currentButton.HighlightTexture,
                        overlay and overlay.AddIconHighlight)
                end,
                getHovered = IsHovered,
            }
        end
    end
    return descriptors
end

local function SkinReagentNames(form, reagentType, id)
    local textStyle = NSkin:GetAppearanceStyle("text", IDs.Scope, id)
    local applied = false
    for _, slot in ipairs(GetReagentSlots(form, reagentType)) do
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
    if not registeredCraftingGroups[id] then
        registeredCraftingGroups[id] = NSkin:RegisterIconGroup({
            id = id,
            module = "Professions", appearanceWindowID = IDs.Scope,
            label = label, kind = "ICON", window = frame, target = parent,
            priority = 100, draggable = false,
            children = function()
                return GetReagentIconDescriptors(form, reagentType)
            end,
            refreshContent = function()
                return SkinReagentNames(form, reagentType, id)
            end,
            appearanceStyles = { "text" },
            appearanceTypeIDs = { "TEXT" },
            editorOptions = {
                { id = "shared.iconAppearance", label = "Icons",
                    presentation = "INLINE", category = "CUSTOMIZE" },
                { id = "shared.textAppearance", label = "Names",
                    category = "CUSTOMIZE" },
            },
            highlightRegions = function()
                return GetVisibleReagentIconSlots(form, reagentType)
            end,
            pixelBorderTargets = function()
                local targets = {}
                for _, slot in ipairs(GetVisibleReagentIconSlots(
                    form, reagentType))
                do
                    if slot.Button then targets[#targets + 1] = slot.Button end
                end
                return targets
            end,
            isEditable = reagentType == Enum.CraftingReagentType.Finishing
                and NeverEditable or function()
                return IsVisible(frame)
                    and #GetVisibleReagentIconSlots(form, reagentType) > 0
            end,
        }) ~= nil
    else
        NSkin:RefreshIconGroup(id)
    end
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
            isEditable = NeverEditable,
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
            hoverRegion = row.CollapseIconAlphaAdd,
            getHovered = IsHovered,
            artworkRegions = CompactRegions(row.LeftPiece, row.CenterPiece,
                row.RightPiece, row.CollapseIcon),
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
            contentRegions = CompactRegions(row.Label, row.Count),
            contentStyle = textStyle,
        }) ~= nil or applied
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

function CraftingSkin:ApplyWindowChrome(frame)
    if not frame then return false end
    NSkin:SkinStandardWindowChrome({
        frame = frame,
        appearanceWindowID = IDs.Scope,
        elementID = CraftingIDs.Window,
        headerControlsID = CraftingIDs.HeaderControls,
        title = frame.TitleContainer and frame.TitleContainer.TitleText,
        headerControls = {
            {
                id = CraftingIDs.HeaderControls .. ".Resize",
                targets = GetResizeTargets(frame),
            },
        },
    })
    NSkin:RegisterSkinningElement(CraftingIDs.Window, {
        module = "Professions", appearanceWindowID = IDs.Scope,
        label = "Professions crafting window", kind = "WINDOW",
        window = frame, target = frame, priority = 0, draggable = false,
    })
    return true
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
    local background = NSkin:CreateFlatBackground(
        bar, "NSkinProfessionsRankBarBackground",
        progressStyle.background, progressBorder)
    if background and bar.Fill then
        background:ClearAllPoints()
        background:SetPoint("TOPLEFT", bar.Fill, "TOPLEFT")
        if bar.ExpansionDropdownButton then
            background:SetPoint("BOTTOMRIGHT",
                bar.ExpansionDropdownButton, "BOTTOMLEFT")
        else
            background:SetPoint("BOTTOMRIGHT", bar.Fill, "BOTTOMRIGHT")
        end
    end
    local pixelBorder = NSkin:GetPixelBorder(
        bar, "NSkinProfessionsRankBarBackgroundBorder")
    if pixelBorder and background then pixelBorder.anchor = background end
    NSkin:SetPixelBorderColor(pixelBorder, unpack(progressBorder))
    NSkin:SetPixelBorderSize(pixelBorder, 1)
    NSkin:SetPixelBorderPadding(pixelBorder, 0)
    if bar.Fill and bar.Fill.SetVertexColor then
        if progressStyle.useCustomColor then
            bar.Fill:SetVertexColor(unpack(progressStyle.color))
        else
            bar.Fill:SetVertexColor(1, 1, 1, 1)
        end
    end
    if bar.Rank and bar.Rank.Text then
        if progressStyle.useCustomTextColor then
            NSkin:SetFontStringColor(bar.Rank.Text,
                unpack(progressStyle.text))
        else
            NSkin:SetFontStringColor(bar.Rank.Text, 1, 1, 1, 1)
        end
    end
    local dropdown = bar.ExpansionDropdownButton
    if dropdown then
        SuppressCraftingRegions(dropdown, "RankDropdownArtwork",
            CompactRegions(dropdown.Texture))
        NSkin:SkinDropdown(dropdown, {
            style = NSkin:GetAppearanceStyle(
                "button", IDs.Scope, CraftingIDs.RankBar),
            menus = { "MENU_PROFESSIONS_RANK_BAR" },
        })
        -- The native button is one pixel taller than Fill. Align only the
        -- owned presentation surface to the bar while retaining Blizzard's
        -- original click target and anchor geometry.
        local dropdownBackground = NSkin:GetFlatBackground(dropdown)
        if dropdownBackground then
            dropdownBackground:ClearAllPoints()
            dropdownBackground:SetPoint(
                "TOPLEFT", dropdown, "TOPLEFT", 1, 0)
            dropdownBackground:SetPoint(
                "BOTTOMRIGHT", dropdown, "BOTTOMRIGHT", -1, 1)
            local dropdownBorder = NSkin:GetPixelBorder(
                dropdown, "NSkinFlatBackgroundBorder")
            if dropdownBorder then dropdownBorder.anchor = dropdownBackground end
        end
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
    NSkin:ResnapPixelBordersForTarget(bar)
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
            isEditable = NeverEditable,
        }) ~= nil
    end

    local center = quality.Center or quality
    local style = NSkin:GetAppearanceStyle(
        "progressBar", IDs.Scope, CraftingIDs.QualityMaker)
    local borderColor = NSkin:GetAppearanceBorderColor(
        "progressBar", style, IDs.Scope, CraftingIDs.QualityMaker)
    -- Center.Background is selected by SetQuality() and is the persistent
    -- visual representation of the current quality tier. It is state, not
    -- decoration, so restore and preserve it above NSkin's flat surface.
    SuppressCraftingRegions(quality, "QualityMeterArtwork", {})
    SuppressCraftingRegions(quality.Border, "QualityMeterBorder",
        GetDirectTextures(quality.Border))
    local background = NSkin:CreateFlatBackground(
        center, "NSkinProfessionsQualityBackground",
        style.background, borderColor)
    if background and center.Background then
        background:ClearAllPoints()
        background:SetAllPoints(center.Background)
        if background.SetDrawLayer then
            background:SetDrawLayer("BACKGROUND", -8)
        end
    end
    local border = NSkin:GetPixelBorder(
        center, "NSkinProfessionsQualityBackgroundBorder")
    if border and center.Background then border.anchor = center.Background end
    NSkin:SetPixelBorderColor(border, unpack(borderColor))
    NSkin:SetPixelBorderSize(border, 1)
    NSkin:SetPixelBorderPadding(border, 0)
    if center.Background and center.Background.SetVertexColor then
        if style.useCustomColor then
            center.Background:SetVertexColor(unpack(style.color))
        else
            center.Background:SetVertexColor(1, 1, 1, 1)
        end
    end
    local fill = center and center.Fill and center.Fill.Bar
    if fill and fill.SetVertexColor then
        if style.useCustomColor then
            fill:SetVertexColor(unpack(style.color))
        else
            fill:SetVertexColor(1, 1, 1, 1)
        end
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
                isEditable = NeverEditable,
            }) == true
    end
    NSkin:ResnapPixelBordersForTarget(center)
    return true
end

local EQUIPMENT_SLOT_KEYS = {
    "Prof0ToolSlot", "Prof1ToolSlot", "Prof0Gear0Slot",
    "Prof1Gear0Slot", "Prof0Gear1Slot", "Prof1Gear1Slot",
    "CookingToolSlot", "CookingGear0Slot", "FishingToolSlot",
}

local function GetEquipmentSlots(page, visibleOnly)
    local slots = {}
    for _, key in ipairs(EQUIPMENT_SLOT_KEYS) do
        local button = page and page[key]
        if button and (not visibleOnly or IsVisible(button)) then
            slots[#slots + 1] = button
        end
    end
    return slots
end

local function GetEquipmentNativeDecorations(button)
    local decorations, seen = {}, {}
    AddProfessionButtonDecorations(decorations, seen, button)
    AddRegion(decorations, seen, GetButtonStateTexture(
        button, "GetNormalTexture", "NormalTexture"))
    return decorations
end

local function GetEquipmentIconDescriptors(page)
    local descriptors = {}
    for _, button in ipairs(GetEquipmentSlots(page, false)) do
        if not IsForbidden(button) then
            descriptors[#descriptors + 1] = {
                target = button,
                textureProvider = GetIconTexture,
                borderOwner = button,
                qualityProvider = GetEquipmentQuality,
                nativeDecorationRegions = function(currentButton)
                    return GetEquipmentNativeDecorations(currentButton)
                end,
                getHovered = IsHovered,
            }
        end
    end
    return descriptors
end

function CraftingSkin:ApplyEquipment(frame, page)
    if _G.InCombatLockdown and _G.InCombatLockdown() then return false end
    if not registeredCraftingGroups[CraftingIDs.Equipment] then
        registeredCraftingGroups[CraftingIDs.Equipment] =
            NSkin:RegisterIconGroup({
                id = CraftingIDs.Equipment,
                module = "Professions", appearanceWindowID = IDs.Scope,
                label = "Profession Equipment", kind = "ICON",
                window = frame, target = page, priority = 40,
                draggable = false,
                children = function()
                    return GetEquipmentIconDescriptors(page)
                end,
                editorOptions = {
                    { id = "shared.iconAppearance", label = "Equipment icons",
                        presentation = "INLINE", category = "CUSTOMIZE" },
                },
                highlightRegions = function()
                    return GetEquipmentSlots(page, true)
                end,
                pixelBorderTargets = function()
                    return GetEquipmentSlots(page, true)
                end,
                isEditable = function()
                    return IsVisible(frame)
                        and #GetEquipmentSlots(page, true) > 0
                        and not (_G.InCombatLockdown
                            and _G.InCombatLockdown())
                end,
            }) ~= nil
    else
        NSkin:RefreshIconGroup(CraftingIDs.Equipment)
    end
    if registeredCraftingGroups[CraftingIDs.Equipment] then
        NSkin:NotifySkinningElementBoundsChanged(CraftingIDs.Equipment)
    end
    return registeredCraftingGroups[CraftingIDs.Equipment]
end

local function GetConcentrateButtons(form, visibleOnly)
    local buttons, seen = {}, {}
    local details = form and form.Details
    local choices = details and details.CraftingChoicesContainer
    local containers = {}
    if choices and choices.ConcentrateContainer then
        containers[#containers + 1] = choices.ConcentrateContainer
    end
    if form and form.Concentrate then
        containers[#containers + 1] = form.Concentrate
    end
    for _, container in ipairs(containers) do
        local button = container and container.ConcentrateToggleButton
        if button and not seen[button]
            and (not visibleOnly or IsVisible(button))
        then
            seen[button] = true
            buttons[#buttons + 1] = button
        end
    end
    return buttons
end

local function GetConcentrateIconDescriptors(form)
    local descriptors = {}
    for _, button in ipairs(GetConcentrateButtons(form, false)) do
        descriptors[#descriptors + 1] = {
            target = button,
            textureProvider = GetConcentrateDisplayedTexture,
            borderOwner = button,
            nativeDecorationRegions = function(currentButton)
                return CompactRegions(
                    GetButtonStateTexture(currentButton,
                        "GetNormalTexture", "NormalTexture"),
                    GetButtonStateTexture(currentButton,
                        "GetPushedTexture", "PushedTexture"))
            end,
            selectedRegion = function(currentButton)
                return GetButtonStateTexture(currentButton,
                    "GetCheckedTexture", "CheckedTexture")
            end,
            getHovered = IsHovered, getSelected = IsChecked,
            refreshOn = { "OnEnable", "OnDisable" },
        }
    end
    return descriptors
end

function CraftingSkin:ApplyConcentration(frame, page, form)
    local applied = false
    local buttons = GetConcentrateButtons(form, false)
    if #buttons > 0 and not registeredCraftingGroups[CraftingIDs.Concentrate] then
        registeredCraftingGroups[CraftingIDs.Concentrate] =
            NSkin:RegisterIconGroup({
                id = CraftingIDs.Concentrate,
                module = "Professions", appearanceWindowID = IDs.Scope,
                label = "Concentration toggle", kind = "ICON",
                window = frame, target = buttons[1], priority = 55,
                draggable = false,
                children = function()
                    return GetConcentrateIconDescriptors(form)
                end,
                editorOptions = {
                    { id = "shared.iconAppearance", label = "Toggle icon",
                        presentation = "INLINE", category = "CUSTOMIZE" },
                },
                highlightRegions = function()
                    return GetConcentrateButtons(form, true)
                end,
                pixelBorderTargets = function()
                    return GetConcentrateButtons(form, true)
                end,
                isEditable = NeverEditable,
            }) ~= nil
    elseif registeredCraftingGroups[CraftingIDs.Concentrate] then
        NSkin:RefreshIconGroup(CraftingIDs.Concentrate)
    end
    applied = registeredCraftingGroups[CraftingIDs.Concentrate] or applied

    local display = page and page.ConcentrationDisplay
    if display and display.Amount then
        local function RefreshDisplayContent()
            local textStyle = NSkin:GetAppearanceStyle(
                "text", IDs.Scope, CraftingIDs.ConcentrationDisplay)
            return NSkin:SkinText(display.Amount, textStyle) == true
        end
        if not registeredCraftingGroups[CraftingIDs.ConcentrationDisplay] then
            registeredCraftingGroups[CraftingIDs.ConcentrationDisplay] =
                NSkin:RegisterIconGroup({
                    id = CraftingIDs.ConcentrationDisplay,
                    module = "Professions",
                    appearanceWindowID = IDs.Scope,
                    label = "Concentration Display", kind = "ICON",
                    window = frame, target = display, priority = 56,
                    draggable = false,
                    children = {
                        {
                            target = display,
                            textureProvider = function(currentDisplay)
                                return currentDisplay.Icon
                            end,
                            borderOwner = display,
                        },
                    },
                    refreshContent = RefreshDisplayContent,
                    appearanceStyles = { "text" },
                    appearanceTypeIDs = { "TEXT" },
                    editorOptions = {
                        { id = "shared.iconAppearance", label = "Icon",
                            presentation = "INLINE",
                            category = "CUSTOMIZE" },
                        { id = "shared.textAppearance", label = "Amount",
                            category = "CUSTOMIZE" },
                    },
                    highlightRegions = function()
                        return CompactRegions(display.Icon, display.Amount)
                    end,
                    pixelBorderTargets = { display },
                    isEditable = function()
                        return IsCraftingVisible(frame, display)
                    end,
                }) ~= nil
        else
            NSkin:RefreshIconGroup(CraftingIDs.ConcentrationDisplay)
        end
        applied = registeredCraftingGroups[CraftingIDs.ConcentrationDisplay]
            or applied
    end
    return applied
end

function CraftingSkin:ApplyDetailsGroup(frame, form)
    local details = form and form.Details
    if not details then return false end
    local element = NSkin:RegisterSimpleMovableElement({
        id = CraftingIDs.Details,
        module = "Professions",
        appearanceWindowID = IDs.Scope,
        label = "Crafting Details",
        kind = "MOVABLE",
        window = frame,
        target = details,
        priority = 145,
        draggable = true,
        highlightRegions = { details },
        isEditable = function()
            return IsCraftingVisible(frame, details)
        end,
    })
    registeredCraftingGroups[CraftingIDs.Details] = element or nil
    if element then
        NSkin:NotifySkinningElementBoundsChanged(CraftingIDs.Details)
    end
    return element ~= nil
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
        { "ReagentsLabel", "Reagents label",
            form and form.Reagents and form.Reagents.Label },
        { "OptionalReagentsLabel", "Optional reagents label",
            form and form.OptionalReagents and form.OptionalReagents.Label },
        { "DetailsLabel", "Crafting details label",
            details and details.Label, true },
        { "ConcentrateLabel", "Concentration label",
            concentrate and concentrate.Label, true },
        { "FinishingLabel", "Finishing reagents label",
            finishing and finishing.Label, true },
    }) do
        applied = RegisterCraftingText(frame,
            CraftingIDs.TextPrefix .. definition[1], definition[2],
            definition[3], 60 + index, definition[4]) ~= nil or applied
    end
    return applied
end

function CraftingSkin:ApplyControls(frame, page, form)
    local applied = false
    for index, definition in ipairs({
        { CraftingIDs.CreateAll, "Craft all", page.CreateAllButton or page.CraftAllButton },
        { CraftingIDs.Create, "Create", page.CreateButton },
    }) do
        local button = definition[3]
        if button then
            local element = NSkin:RegisterActionButton({
                id = definition[1], module = "Professions",
                appearanceWindowID = IDs.Scope, label = definition[2],
                window = frame, target = button, priority = 150 + index,
                isEditable = function()
                    return IsCraftingVisible(frame, button)
                end,
            })
            RefreshTypedElement(element)
            applied = element ~= nil or applied
        end
    end
    local input = page.CreateMultipleInputBox
    if input then
        local element = NSkin:RegisterEditBox({
            id = CraftingIDs.CreateCount, module = "Professions",
            appearanceWindowID = IDs.Scope, label = "Craft count",
            window = frame, target = input, priority = 155,
            decrementButton = input.DecrementButton,
            incrementButton = input.IncrementButton,
            appearanceStyles = { "button" },
            appearanceTypeIDs = { "ACTION_BUTTON" },
            highlightRegions = CompactRegions(input.DecrementButton,
                input, input.IncrementButton),
            pixelBorderTargets = CompactRegions(input.DecrementButton,
                input, input.IncrementButton),
            isEditable = function()
                return IsCraftingVisible(frame, input)
            end,
        })
        RefreshTypedElement(element)
        applied = element ~= nil or applied
    end
    for index, checkbox in ipairs({
        form and form.TrackRecipeCheckbox,
        form and form.AllocateBestQualityCheckbox,
    }) do
        if checkbox then
            local element = NSkin:RegisterCheckbox({
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
            })
            RefreshTypedElement(element)
            applied = element ~= nil or applied
        end
    end
    local recipeList = page.RecipeList
    if recipeList and recipeList.SearchBox then
        local element = NSkin:RegisterSearchBox({
            id = CraftingIDs.Search, module = "Professions",
            appearanceWindowID = IDs.Scope, label = "Recipe search",
            window = frame, target = recipeList.SearchBox, priority = 160,
            isEditable = function()
                return IsCraftingVisible(frame, recipeList.SearchBox)
            end,
        })
        RefreshTypedElement(element)
        applied = element ~= nil or applied
    end
    if recipeList and recipeList.FilterDropdown then
        local element = NSkin:RegisterDropdown({
            id = CraftingIDs.Filter, module = "Professions",
            appearanceWindowID = IDs.Scope, label = "Recipe filter",
            window = frame, target = recipeList.FilterDropdown, priority = 161,
            menus = { "MENU_PROFESSIONS_FILTER" },
            isEditable = function()
                return IsCraftingVisible(frame, recipeList.FilterDropdown)
            end,
        })
        RefreshTypedElement(element)
        applied = element ~= nil or applied
    end
    return applied
end

function CraftingSkin:ApplyTabs(frame)
    local tabSystem = frame and frame.TabSystem
    if not tabSystem then return false end
    local tabs = {}
    if type(frame.GetTabSet) == "function"
        and type(frame.GetTabButton) == "function"
    then
        for _, tabID in ipairs(frame:GetTabSet() or {}) do
            local tab = frame:GetTabButton(tabID)
            if tab then tabs[#tabs + 1] = tab end
        end
    elseif type(tabSystem.tabs) == "table" then
        for _, tab in ipairs(tabSystem.tabs) do
            if tab then tabs[#tabs + 1] = tab end
        end
    end
    if #tabs == 0 then return false end

    local style = NSkin:GetAppearanceStyle(
        "tab", IDs.Scope, CraftingIDs.Tabs)
    local border = NSkin:GetAppearanceBorderColor(
        "tab", style, IDs.Scope, CraftingIDs.Tabs)
    for _, tab in ipairs(tabs) do
        NSkin:SkinTab(tab,
            tab.IsSelected and tab:IsSelected() or false, style, border)
    end

    if not registeredCraftingGroups[CraftingIDs.Tabs] then
        registeredCraftingGroups[CraftingIDs.Tabs] =
            NSkin:RegisterTabGroup(CraftingIDs.Tabs, {
                module = "Professions", appearanceWindowID = IDs.Scope,
                label = "Profession tabs", window = frame, tabs = tabs,
                owner = frame, orientation = "HORIZONTAL", edge = "BOTTOM",
                priority = 170, draggable = false,
                isEditable = function()
                    return IsVisible(frame) and IsVisible(tabSystem)
                end,
            }) == true
    end
    NSkin:ApplyTabGroupLayout(CraftingIDs.Tabs)
    return registeredCraftingGroups[CraftingIDs.Tabs]
end

function CraftingSkin:HookLifecycle(frame, page, form)
    if craftingLifecycleHooked then return end
    if frame.HookScript then frame:HookScript("OnShow", function() CraftingSkin:Apply() end) end
    if page.HookScript then page:HookScript("OnShow", function() CraftingSkin:Apply() end) end
    if _G.hooksecurefunc then
        if type(frame.UpdateTabs) == "function" then
            pcall(_G.hooksecurefunc, frame, "UpdateTabs", function()
                CraftingSkin:ApplyTabs(frame)
            end)
        end
        if type(page.Refresh) == "function" then
            pcall(_G.hooksecurefunc, page, "Refresh", function()
                CraftingSkin:ApplyEquipment(frame, page)
                CraftingSkin:ApplyConcentration(frame, page, form)
                CraftingSkin:ApplyControls(frame, page, form)
            end)
        end
        if page.RankBar and type(page.RankBar.Update) == "function" then
            pcall(_G.hooksecurefunc, page.RankBar, "Update", function()
                ApplyHybridRankBar(frame, page)
            end)
        end
        if type(form.Init) == "function" then
            pcall(_G.hooksecurefunc, form, "Init", function()
                CraftingSkin:ApplyDetailsGroup(frame, form)
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
                ApplyOutputIcon(frame, form)
                CraftingSkin:ApplyConcentration(frame, page, form)
            end)
        end
        if type(_G.OpenProfessionsItemFlyout) == "function" then
            pcall(_G.hooksecurefunc, "OpenProfessionsItemFlyout",
                function(_, _, behavior)
                    local flyout = behavior and behavior.flyout
                    if flyout then RegisterReagentFlyout(frame, flyout) end
                end)
        end
        local qualityDialog = form.QualityDialog
        if qualityDialog then
            for _, method in ipairs({ "Open", "Setup" }) do
                if type(qualityDialog[method]) == "function" then
                    pcall(_G.hooksecurefunc, qualityDialog, method, function()
                        RegisterQualityDialog(frame, qualityDialog)
                    end)
                end
            end
        end
        if form.Details and type(form.Details.SetStats) == "function" then
            pcall(_G.hooksecurefunc, form.Details, "SetStats", function()
                RegisterStatLines(frame, form.Details)
                ApplyQualityMaker(frame, form)
            end)
        end
        local quality = form.Details
            and (form.Details.QualityMaker or form.Details.QualityMeter)
        for _, method in ipairs({ "SetQuality", "SetBarAtlas" }) do
            if quality and type(quality[method]) == "function" then
                pcall(_G.hooksecurefunc, quality, method, function()
                    ApplyQualityMaker(frame, form)
                end)
            end
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
    ApplyOutputIcon(frame, form)
    RegisterQualityDialog(frame, form.QualityDialog)
    return true
end

function CraftingSkin:Apply()
    local frame = _G.ProfessionsFrame
    local page = frame and frame.CraftingPage
    local form = page and page.SchematicForm
    if not frame or not page or not form then return false end
    local applied = self:ApplyWindowChrome(frame)
    applied = self:ApplyDetailsGroup(frame, form) or applied
    applied = ApplyHybridRankBar(frame, page) or applied
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
