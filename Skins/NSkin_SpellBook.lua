local _, NSkin = ...

local SpellBookSkin = NSkin:NewModule("SpellBook")

local IDs = {
    AppearanceWindow = "PlayerSpells.SpellBook",
    Window = "SpellBook.Window",
    HeaderControls = "SpellBook.HeaderControls",
    ExpandCollapse = "SpellBook.ExpandCollapse",
    MainTabs = "SpellBook.MainTabs",
    CategoryTabs = "SpellBook.CategoryTabs",
    Headers = "SpellBook.Headers",
    Spells = {
        Icons = "SpellBook.Spells.Icons",
        Names = "SpellBook.Spells.Names",
        SecondaryText = "SpellBook.Spells.SecondaryText",
    },
    AssistedCombat = {
        Icon = "SpellBook.AssistedCombat.Icon",
        Label = "SpellBook.AssistedCombat.Label",
    },
    Talents = {
        ApplyButton = "SpellBook.Talents.ApplyButton",
        SearchBox = "SpellBook.Talents.SearchBox",
        LoadoutDropdown = "SpellBook.Talents.LoadoutDropdown",
    },
    Specializations = {
        Window = "SpellBook.Specializations.Window",
        ElementPrefix = "SpellBook.Specializations.Spec.",
    },
    Search = { Group = "SpellBook.Search", Accessory = "SpellBook.Search.Cog" },
    Pagination = {
        Group = "SpellBook.Pagination",
        Previous = "SpellBook.Pagination.Previous",
        Next = "SpellBook.Pagination.Next",
        Text = "SpellBook.Pagination.Text",
    },
}
local State = {
    initialized = false,
    original = {},
    assistedCombatDivider = nil,
    paginationController = nil,
    searchController = nil,
    specializationContentsHooked = false,
    specializationWindowRegistered = false,
}
local Adapters = {}

NSkin:RegisterAppearanceScope(IDs.AppearanceWindow, { label = "Spellbook" })

local iconDisposition = NSkin:RegisterColumnDisposition(
    "SpellBook.Spells.Disposition", {
        module = "SpellBook",
        optionKey = "iconsPerRow",
        allowed = { 2, 3, 4 },
        get = function()
            local playerSpells = _G.PlayerSpellsFrame
            local spellBook = playerSpells and playerSpells.SpellBookFrame
            local pagedSpells = spellBook and spellBook.PagedSpellsFrame
            return pagedSpells and pagedSpells.columnsPerRow
        end,
        set = function(columns)
            local playerSpells = _G.PlayerSpellsFrame
            local spellBook = playerSpells and playerSpells.SpellBookFrame
            local pagedSpells = spellBook and spellBook.PagedSpellsFrame
            if not pagedSpells then return false end
            pagedSpells.columnsPerRow = columns
        end,
        refresh = function()
            local playerSpells = _G.PlayerSpellsFrame
            local spellBook = playerSpells and playerSpells.SpellBookFrame
            if spellBook and type(spellBook.UpdateDisplayedSpells) == "function" then
                spellBook:UpdateDisplayedSpells(true, false)
            end
        end,
    })
local function RoundOne(value)
    value = tonumber(value) or 0
    if value >= 0 then return math.floor(value * 10 + 0.5) / 10 end
    return math.ceil(value * 10 - 0.5) / 10
end









function NSkin:GetSpellBookHeaderOffset()
    local options = self:GetModuleOptions("SpellBook", false)
    local offset = options and options.headerOffset
    return { offsetX = offset and tonumber(offset.x) or 0,
        offsetY = offset and tonumber(offset.y) or 0 }
end

function NSkin:SetSpellBookHeaderOffset(offsetX, offsetY)
    offsetX = math.max(-200, math.min(200, math.floor((tonumber(offsetX) or 0) + 0.5)))
    offsetY = math.max(-100, math.min(100, math.floor((tonumber(offsetY) or 0) + 0.5)))
    local options = self:GetModuleOptions("SpellBook", offsetX ~= 0 or offsetY ~= 0)
    if options then
        options.headerOffset = (offsetX ~= 0 or offsetY ~= 0)
            and { x = offsetX, y = offsetY } or nil
        local profile = self:GetProfile()
        if not next(options) then profile.moduleOptions.SpellBook = nil end
        if profile.moduleOptions and not next(profile.moduleOptions) then
            profile.moduleOptions = nil
        end
    end
    if SpellBookSkin.RefreshHeaders then SpellBookSkin:RefreshHeaders() end
    return true
end

local function CopyPlacement(placement)
    return {
        mode = placement.mode,
        edge = placement.edge,
        side = placement.side,
        alignment = placement.alignment,
        alongOffset = placement.alongOffset ~= nil and RoundOne(placement.alongOffset) or nil,
        edgeOffset = placement.edgeOffset ~= nil and RoundOne(placement.edgeOffset) or nil,
        relativeTo = placement.relativeTo,
        point = placement.point,
        relativePoint = placement.relativePoint,
        offsetX = placement.offsetX,
        offsetY = placement.offsetY,
        x = placement.x ~= nil and RoundOne(placement.x) or nil,
        y = placement.y ~= nil and RoundOne(placement.y) or nil,
    }
end

local function GetMainTabPlacementOptions()
    local options = NSkin:GetModuleOptions("SpellBook", false)
    return options and options.mainTabsPlacement
end





local function HasMainTabPlacement()
    return GetMainTabPlacementOptions() ~= nil
end

local function GetMainTabPlacement()
    local playerSpells = _G.PlayerSpellsFrame
    return CopyPlacement(GetMainTabPlacementOptions()
        or NSkin:GetCurrentWindowElementPlacement(
            playerSpells, playerSpells and playerSpells.TabSystem)
        or NSkin:GetTabPlacement())
end

local function SetMainTabPlacement(_, placement)
    if type(placement) ~= "table" then return false end
    local saved = CopyPlacement(placement)
    if placement.mode == "GRID" then
        local x, y = tonumber(placement.x), tonumber(placement.y)
        if not x or not y then return false end
        saved.x = math.max(-2000, math.min(2000, RoundOne(x)))
        saved.y = math.max(-2000, math.min(2000, RoundOne(y)))
    else
        if (placement.edge ~= "TOP" and placement.edge ~= "BOTTOM")
            or (placement.side ~= "INSIDE" and placement.side ~= "OUTSIDE")
            or (placement.alignment ~= "LEFT" and placement.alignment ~= "CENTER"
                and placement.alignment ~= "RIGHT")
        then return false end
        saved.alongOffset = math.max(-2000, math.min(2000,
            RoundOne(placement.alongOffset)))
        saved.edgeOffset = math.max(-2000, math.min(2000,
            RoundOne(placement.edgeOffset)))
    end
    local options = NSkin:GetModuleOptions("SpellBook", true)
    options.mainTabsPlacement = saved
    NSkin:ApplyTabGroupLayout(IDs.MainTabs)
    return true
end

local function ResetMainTabPlacement()
    local options = NSkin:GetModuleOptions("SpellBook", false)
    if options then
        options.mainTabsPlacement = nil
        local profile = NSkin:GetProfile()
        if not next(options) then profile.moduleOptions.SpellBook = nil end
        if profile.moduleOptions and not next(profile.moduleOptions) then
            profile.moduleOptions = nil
        end
    end
    return NSkin:RestoreTabGroupOriginalPlacement(IDs.MainTabs)
end

function NSkin:ResetSpellBookTabPlacements()
    if _G.InCombatLockdown and _G.InCombatLockdown() then return false end
    local options = self:GetModuleOptions("SpellBook", false)
    if options then
        options.mainTabsPlacement = nil
        options.categoryTabsPlacement = nil
        local profile = self:GetProfile()
        if not next(options) then profile.moduleOptions.SpellBook = nil end
        if profile.moduleOptions and not next(profile.moduleOptions) then
            profile.moduleOptions = nil
        end
    end
    local category = self:GetTabGroup(IDs.CategoryTabs)
    if category then Adapters.RestoreCategoryTabAnchors(category.container) end
    self:RestoreTabGroupOriginalPlacement(IDs.MainTabs)
    return true
end

local function GetCategoryTabPlacementOptions()
    local options = NSkin:GetModuleOptions("SpellBook", false)
    return options and options.categoryTabsPlacement
end

local function HasCategoryTabPlacement()
    return GetCategoryTabPlacementOptions() ~= nil
end

local function GetCategoryTabPlacement()
    local playerSpells = _G.PlayerSpellsFrame
    local spellBook = playerSpells and playerSpells.SpellBookFrame
    return CopyPlacement(GetCategoryTabPlacementOptions()
        or NSkin:GetCurrentWindowElementPlacement(
            playerSpells, spellBook and spellBook.CategoryTabSystem)
        or NSkin:GetTabPlacement())
end

local function SetCategoryTabPlacement(_, placement)
    if type(placement) ~= "table" then return false end
    if placement.mode == "GRID" then
        local x, y = tonumber(placement.x), tonumber(placement.y)
        if not x or not y then return false end
        local options = NSkin:GetModuleOptions("SpellBook", true)
        options.categoryTabsPlacement = CopyPlacement(placement)
        options.categoryTabsPlacement.x = math.max(-2000, math.min(2000, RoundOne(x)))
        options.categoryTabsPlacement.y = math.max(-2000, math.min(2000, RoundOne(y)))
        NSkin:ApplyTabGroupLayout(IDs.CategoryTabs)
        return true
    end
    local edge = placement.edge
    local side = placement.side
    local alignment = placement.alignment
    local alongOffset = tonumber(placement.alongOffset)
    local edgeOffset = tonumber(placement.edgeOffset)
    if (edge ~= "TOP" and edge ~= "BOTTOM")
        or (side ~= "INSIDE" and side ~= "OUTSIDE")
        or (alignment ~= "LEFT" and alignment ~= "CENTER" and alignment ~= "RIGHT")
        or not alongOffset or not edgeOffset
    then
        return false
    end
    local options = NSkin:GetModuleOptions("SpellBook", true)
    options.categoryTabsPlacement = {
        edge = edge,
        side = side,
        alignment = alignment,
        alongOffset = math.max(-2000, math.min(2000, RoundOne(alongOffset))),
        edgeOffset = math.max(-2000, math.min(2000, RoundOne(edgeOffset))),
        relativeTo = placement.relativeTo,
        point = placement.point,
        relativePoint = placement.relativePoint,
        offsetX = placement.offsetX,
        offsetY = placement.offsetY,
    }
    NSkin:ApplyTabGroupLayout(IDs.CategoryTabs)
    return true
end

function Adapters.RestoreCategoryTabAnchors(tabSystem)
    if not tabSystem or not State.original.categoryTabPoints
        or (_G.InCombatLockdown and _G.InCombatLockdown())
    then
        return false
    end
    tabSystem:ClearAllPoints()
    for i = 1, #State.original.categoryTabPoints do
        tabSystem:SetPoint(unpack(State.original.categoryTabPoints[i]))
    end
    if tabSystem.MarkDirty then tabSystem:MarkDirty() end
    NSkin:NotifySkinningElementBoundsChanged(IDs.CategoryTabs)
    return true
end

local function ResetCategoryTabPlacement(group)
    local options = NSkin:GetModuleOptions("SpellBook", false)
    if options then
        options.categoryTabsPlacement = nil
        local profile = NSkin:GetProfile()
        if not next(options) then profile.moduleOptions.SpellBook = nil end
        if profile.moduleOptions and not next(profile.moduleOptions) then
            profile.moduleOptions = nil
        end
    end
    return Adapters.RestoreCategoryTabAnchors(group.container)
end


local function SkinSpellBookTabs()
    local playerSpells = _G.PlayerSpellsFrame
    local spellBook = playerSpells and playerSpells.SpellBookFrame
    if not spellBook then return end

    local categoryStyle = NSkin:GetAppearanceStyle(
        "tab", IDs.AppearanceWindow, IDs.CategoryTabs)
    local categoryBorder = NSkin:GetAppearanceBorderColor(
        "tab", categoryStyle, IDs.AppearanceWindow, IDs.CategoryTabs)
    NSkin:SkinTabSystem(spellBook.CategoryTabSystem, categoryStyle, categoryBorder)
    if NSkin:GetTabGroup(IDs.CategoryTabs) then
        NSkin:ApplyTabGroupLayout(IDs.CategoryTabs)
    end
    local mainStyle = NSkin:GetAppearanceStyle("tab", IDs.AppearanceWindow, IDs.MainTabs)
    local mainBorder = NSkin:GetAppearanceBorderColor(
        "tab", mainStyle, IDs.AppearanceWindow, IDs.MainTabs)
    NSkin:SkinTabSystem(playerSpells.TabSystem, mainStyle, mainBorder)
    if NSkin:GetTabGroup(IDs.MainTabs) then
        NSkin:ApplyTabGroupLayout(IDs.MainTabs)
    end
end

local function GetSpellBookResizeButtons(playerSpells, spellBook)
    if not playerSpells or not spellBook then return {} end

    local expandFrame = playerSpells.MaximizeMinimizeButton
    local maximizeButton = expandFrame and expandFrame.MaximizeButton
    local minimizeButton = expandFrame and expandFrame.MinimizeButton

    local targets = {}
    if maximizeButton then
        targets[#targets + 1] = {
            target = maximizeButton,
            glyph = "maximize",
        }
    end
    if minimizeButton then
        targets[#targets + 1] = {
            target = minimizeButton,
            glyph = "minimize",
        }
    end
    return targets
end

local function GetAssistedCombatDivider(frame)
    if not frame or not frame.GetRegions then return nil end
    for _, region in ipairs({ frame:GetRegions() }) do
        if region and region.GetObjectType
            and region:GetObjectType() == "Texture"
        then
            return region
        end
    end
    return nil
end

local function SkinAssistedCombat(frame)
    if not frame then return end

    local divider = GetAssistedCombatDivider(frame)
    if divider then ConcealTexture(divider) end

    local button = frame.Button
    local icon = button and button.Icon
    if button and icon then
        local native = {}
        if button.Border then native[#native + 1] = button.Border end
        NSkin:RegisterIcon({
            id = IDs.AssistedCombat.Icon,
            module = "SpellBook",
            appearanceWindowID = IDs.AppearanceWindow,
            label = "Assisted Combat spell",
            window = _G.PlayerSpellsFrame,
            target = button,
            texture = icon,
            borderOwner = button,
            nativeDecorationRegions = native,
            priority = 66,
            highlightRegions = { button },
            isEditable = function()
                return frame:IsVisible() and button:IsVisible()
            end,
        })
    end

    if frame.Label then
        NSkin:RegisterTextElement({
            id = IDs.AssistedCombat.Label,
            module = "SpellBook",
            appearanceWindowID = IDs.AppearanceWindow,
            label = "Assisted Combat label",
            window = _G.PlayerSpellsFrame,
            target = frame.Label,
            priority = 67,
            highlightRegions = { frame.Label },
            isEditable = function()
                return frame:IsVisible() and frame.Label:IsVisible()
            end,
        })
    end

    if not State.assistedCombatDivider then
        State.assistedCombatDivider = frame:CreateTexture(nil, "ARTWORK", nil, 1)
        State.assistedCombatDivider:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -2)
        State.assistedCombatDivider:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 2)
        State.assistedCombatDivider:SetWidth(1)
    end
    State.assistedCombatDivider:SetColorTexture(
        unpack(NSkin:GetStyle("window").header.divider))
end


local function SkinSpellBookControls()
    local playerSpells = _G.PlayerSpellsFrame
    local spellBook = playerSpells and playerSpells.SpellBookFrame
    local pagedSpells = spellBook and spellBook.PagedSpellsFrame
    if not spellBook then return end
    if State.paginationController then State.paginationController:Refresh() end

    local resizeTargets = GetSpellBookResizeButtons(playerSpells, spellBook)
    NSkin:SkinStandardWindowChrome({
        frame = playerSpells,
        appearanceWindowID = IDs.AppearanceWindow,
        elementID = IDs.Window,
        headerControlsID = IDs.HeaderControls,
        headerControls = {
            {
                id = IDs.ExpandCollapse,
                targets = resizeTargets,
            },
        },
    })
    SkinSpellBookTabs()
    local searchStyle = NSkin:GetAppearanceStyle(
        "searchBox", IDs.AppearanceWindow, IDs.Search.Group)
    NSkin:SkinSearchBox(spellBook.SearchBox, searchStyle,
        NSkin:GetAppearanceBorderColor(
            "searchBox", searchStyle, IDs.AppearanceWindow, IDs.Search.Group))
    NSkin:SkinPagingControls(pagedSpells and pagedSpells.PagingControls)
    SkinAssistedCombat(spellBook.AssistedCombatRotationSpellFrame)
end

local function IsTalentControlVisible(talents, control)
    return talents and control and talents:IsVisible() and control:IsVisible()
end

local function RegisterTalentControls(playerSpells)
    local talents = playerSpells and playerSpells.TalentsFrame
    local loadSystem = talents and talents.LoadSystem
    local loadoutDropdown = loadSystem and loadSystem.GetDropdown
        and loadSystem:GetDropdown() or (loadSystem and loadSystem.Dropdown)
    if not talents then return false end

    -- The PlayerSpellsFrame is shared by Spellbook and Talents. Reapply the
    -- same registered window chrome here so opening either tab has identical
    -- shared chrome without creating a second overlapping window element.
    NSkin:SkinStandardWindowChrome({
        frame = playerSpells,
        appearanceWindowID = IDs.AppearanceWindow,
        elementID = IDs.Window,
        headerControlsID = IDs.HeaderControls,
        headerControls = {
            {
                id = IDs.ExpandCollapse,
                targets = GetSpellBookResizeButtons(
                    playerSpells, playerSpells.SpellBookFrame),
            },
        },
    })

    local applied = NSkin:RegisterActionButton({
        id = IDs.Talents.ApplyButton,
        module = "SpellBook",
        appearanceWindowID = IDs.AppearanceWindow,
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
        id = IDs.Talents.SearchBox,
        module = "SpellBook",
        appearanceWindowID = IDs.AppearanceWindow,
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
        id = IDs.Talents.LoadoutDropdown,
        module = "SpellBook",
        appearanceWindowID = IDs.AppearanceWindow,
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
    return applied
end

local function GetSpecializationElementID(specID, elementName)
    return IDs.Specializations.ElementPrefix .. tostring(specID) .. "." .. elementName
end

local function IsSpecializationControlVisible(specFrame, control)
    return specFrame and control and specFrame:IsVisible() and control:IsVisible()
end

local function RegisterSpecializationContent(specFrame, contentFrame)
    local specializationInfo = _G.C_SpecializationInfo
    local getSpecializationInfo = specializationInfo
        and specializationInfo.GetSpecializationInfo
    local specIndex = contentFrame and contentFrame.specIndex
    local specID, specName
    if type(getSpecializationInfo) == "function" and specIndex then
        local sex = _G.UnitSex and _G.UnitSex("player")
        specID, specName = getSpecializationInfo(
            specIndex, false, false, nil, sex)
    end
    if not specID then return false end

    local function RegisterText(elementName, label, target, priority)
        if not target then return false end
        return NSkin:RegisterTextElement({
            id = GetSpecializationElementID(specID, elementName),
            module = "SpellBook",
            appearanceWindowID = IDs.AppearanceWindow,
            label = (specName or "Specialization") .. " " .. label,
            window = specFrame,
            target = target,
            priority = priority,
            highlightRegions = { target },
            isEditable = function()
                return IsSpecializationControlVisible(specFrame, target)
            end,
        }) ~= nil
    end

    local activateButton = contentFrame.ActivateButton
    local applied = false
    if activateButton then
        applied = NSkin:RegisterActionButton({
            id = GetSpecializationElementID(specID, "ActivateButton"),
            module = "SpellBook",
            appearanceWindowID = IDs.AppearanceWindow,
            label = (specName or "Specialization") .. " activate button",
            window = specFrame,
            target = activateButton,
            priority = 75,
            highlightRegions = { activateButton },
            isEditable = function()
                return IsSpecializationControlVisible(specFrame, activateButton)
            end,
        }) ~= nil
    end

    applied = RegisterText("SpecName", "name", contentFrame.SpecName, 76) or applied
    applied = RegisterText("RoleName", "role name",
        contentFrame.RoleName or contentFrame.roleName, 77) or applied
    applied = RegisterText("Description", "description",
        contentFrame.Description, 78) or applied
    applied = RegisterText("SampleAbilityText", "sample ability text",
        contentFrame.SampleAbilityText, 79) or applied
    applied = RegisterText("ActivatedText", "active text",
        contentFrame.ActivatedText or contentFrame.activatedText, 80) or applied
    return applied
end

local function RegisterSpecializationControls(playerSpells)
    local specFrame = playerSpells and playerSpells.SpecFrame
    if not specFrame then return false end

    NSkin:SkinStandardWindowChrome({
        frame = specFrame,
        appearanceWindowID = IDs.AppearanceWindow,
        elementID = IDs.Specializations.Window,
        skinCloseButton = false,
    })
    if not State.specializationWindowRegistered then
        State.specializationWindowRegistered = NSkin:RegisterSkinningElement(
            IDs.Specializations.Window, {
                label = "Specializations window",
                kind = "WINDOW",
                module = "SpellBook",
                appearanceWindowID = IDs.AppearanceWindow,
                window = specFrame,
                target = specFrame,
                priority = 1,
                draggable = false,
                isEditable = function()
                    return specFrame:IsVisible()
                end,
            }) == true
    end

    if not State.specializationContentsHooked and _G.hooksecurefunc
        and type(specFrame.UpdateSpecContents) == "function"
    then
        _G.hooksecurefunc(specFrame, "UpdateSpecContents", function()
            RegisterSpecializationControls(playerSpells)
        end)
        State.specializationContentsHooked = true
    end

    local pool = specFrame.SpecContentFramePool
    if not pool or type(pool.EnumerateActive) ~= "function" then return true end
    for contentFrame in pool:EnumerateActive() do
        RegisterSpecializationContent(specFrame, contentFrame)
    end
    return true
end


local function GetActiveSpellBookItems(pagedSpells)
    local items = {}
    if not pagedSpells or not pagedSpells.EnumerateFrames then return items end
    for _, frame in pagedSpells:EnumerateFrames() do
        if frame.HasValidData and frame:HasValidData()
            and frame.Button and frame.Button.Icon
        then
            items[#items + 1] = frame
        end
    end
    return items
end

local function GetSpellIconNativeDecorations(item)
    local button = item and item.Button
    local regions = {}
    if item and item.Backplate then regions[#regions + 1] = item.Backplate end
    if button and button.Border then regions[#regions + 1] = button.Border end
    if button and button.BorderSheen then
        regions[#regions + 1] = button.BorderSheen
    end
    return regions
end

local function ApplySpellTextAppearance(fontString, appearanceID)
    if not fontString then return false end
    local style = NSkin:GetAppearanceStyle(
        "text", IDs.AppearanceWindow, appearanceID)
    return NSkin:SkinText(fontString, style) == true
end

local function RefreshSpellNameAppearance(pagedSpells)
    local changed = false
    for _, item in ipairs(GetActiveSpellBookItems(pagedSpells)) do
        changed = ApplySpellTextAppearance(
            item.Name, IDs.Spells.Names) or changed
    end
    NSkin:NotifySkinningElementBoundsChanged(IDs.Spells.Names)
    return changed
end

local function RefreshSpellSecondaryTextAppearance(pagedSpells)
    local changed = false
    for _, item in ipairs(GetActiveSpellBookItems(pagedSpells)) do
        changed = ApplySpellTextAppearance(
            item.SubName, IDs.Spells.SecondaryText) or changed
        changed = ApplySpellTextAppearance(
            item.RequiredLevel, IDs.Spells.SecondaryText) or changed
    end
    NSkin:NotifySkinningElementBoundsChanged(IDs.Spells.SecondaryText)
    return changed
end

local function RegisterSpellBookContentFamilies(playerSpells, spellBook)
    local pagedSpells = spellBook and spellBook.PagedSpellsFrame
    if not pagedSpells then return false end

    local icons = NSkin:RegisterIconGroup({
        id = IDs.Spells.Icons,
        module = "SpellBook",
        appearanceWindowID = IDs.AppearanceWindow,
        label = "Spell icons",
        window = playerSpells,
        target = pagedSpells,
        priority = 68,
        draggable = false,
        children = function()
            local children = {}
            for _, item in ipairs(GetActiveSpellBookItems(pagedSpells)) do
                local button = item.Button
                local isPassive = item.spellBookItemInfo
                    and item.spellBookItemInfo.isPassive
                children[#children + 1] = {
                    target = button,
                    texture = button.Icon,
                    borderOwner = button,
                    nativeDecorationRegions =
                        GetSpellIconNativeDecorations(item),
                    shape = isPassive and "circle" or nil,
                    refreshOn = { "OnShow", "OnEnter", "OnLeave" },
                }
            end
            return children
        end,
        highlightRegions = function()
            local regions = {}
            for _, item in ipairs(GetActiveSpellBookItems(pagedSpells)) do
                regions[#regions + 1] = item.Button
            end
            return regions
        end,
        pixelBorderTargets = function()
            local regions = {}
            for _, item in ipairs(GetActiveSpellBookItems(pagedSpells)) do
                regions[#regions + 1] = item.Button
            end
            return regions
        end,
        isEditable = function()
            return spellBook:IsVisible()
                and #GetActiveSpellBookItems(pagedSpells) > 0
        end,
    })

    local function RegisterTextFamily(id, label, priority, refresh, regions)
        return NSkin:RegisterSkinningElement(id, {
            module = "SpellBook",
            appearanceWindowID = IDs.AppearanceWindow,
            label = label,
            kind = "TEXT",
            window = playerSpells,
            target = pagedSpells,
            priority = priority,
            draggable = false,
            appearanceStyles = { "text" },
            appearanceTypeIDs = { "TEXT" },
            editorOptions = {
                { id = "shared.textAppearance", label = "Text",
                    category = "CUSTOMIZE" },
            },
            highlightRegions = regions,
            refreshAppearance = function()
                return refresh(pagedSpells)
            end,
            refreshLayout = function()
                return refresh(pagedSpells)
            end,
            isEditable = function()
                return spellBook:IsVisible()
                    and #GetActiveSpellBookItems(pagedSpells) > 0
            end,
        })
    end

    local names = RegisterTextFamily(
        IDs.Spells.Names, "Spell names", 69,
        RefreshSpellNameAppearance,
        function()
            local regions = {}
            for _, item in ipairs(GetActiveSpellBookItems(pagedSpells)) do
                if item.Name and item.Name:IsShown() then
                    regions[#regions + 1] = item.Name
                end
            end
            return regions
        end)

    local secondary = RegisterTextFamily(
        IDs.Spells.SecondaryText, "Spell secondary text", 70,
        RefreshSpellSecondaryTextAppearance,
        function()
            local regions = {}
            for _, item in ipairs(GetActiveSpellBookItems(pagedSpells)) do
                if item.SubName and item.SubName:IsShown() then
                    regions[#regions + 1] = item.SubName
                end
                if item.RequiredLevel and item.RequiredLevel:IsShown() then
                    regions[#regions + 1] = item.RequiredLevel
                end
            end
            return regions
        end)

    RefreshSpellNameAppearance(pagedSpells)
    RefreshSpellSecondaryTextAppearance(pagedSpells)
    return icons ~= nil or names == true or secondary == true
end

local function SkinSpellBookItem(item)
    if not item or not item.Button then return end

    local button = item.Button
    local icon = button.Icon
    if not icon then return end

    local spellInfo = item.spellBookItemInfo
    local isPassive = spellInfo and spellInfo.isPassive
    local iconStyle = NSkin:GetAppearanceStyle(
        "icon", IDs.AppearanceWindow, IDs.Spells.Icons)
    local iconBorderColor = NSkin:GetAppearanceBorderColor(
        "icon", iconStyle, IDs.AppearanceWindow, IDs.Spells.Icons)
    NSkin:SkinIcon(button, {
        texture = icon,
        style = iconStyle,
        borderColor = iconBorderColor,
        shape = isPassive and "circle" or nil,
        nativeDecorationRegions = GetSpellIconNativeDecorations(item),
    })

    if button.Cooldown then
        button.Cooldown:ClearAllPoints()
        button.Cooldown:SetAllPoints(icon)
    end

    ApplySpellTextAppearance(item.Name, IDs.Spells.Names)
    ApplySpellTextAppearance(item.SubName, IDs.Spells.SecondaryText)
    ApplySpellTextAppearance(item.RequiredLevel, IDs.Spells.SecondaryText)
end

local function SkinSpellBookHeader(header)
    if not header then return end
    local style = NSkin:GetAppearanceStyle(
        "sectionHeader", IDs.AppearanceWindow, IDs.Headers)
    local decorations = {}
    if header.Backplate then decorations[#decorations + 1] = header.Backplate end
    if header.Border then decorations[#decorations + 1] = header.Border end
    NSkin:SkinSectionHeader(header, {
        style = style,
        text = header.Text,
        offset = NSkin:GetSpellBookHeaderOffset(),
        underline = { left = -8, right = -60, y = 12 },
        nativeDecorations = decorations,
    })
end

local function SkinActiveSpellBookItems()
    local playerSpells = _G.PlayerSpellsFrame
    local spellBook = playerSpells and playerSpells.SpellBookFrame
    local pagedSpells = spellBook and spellBook.PagedSpellsFrame
    if pagedSpells and pagedSpells.EnumerateFrames then
        for _, frame in pagedSpells:EnumerateFrames() do
            if frame.HasValidData and frame:HasValidData() then
                SkinSpellBookItem(frame)
            elseif frame.Text then
                SkinSpellBookHeader(frame)
            end
        end
    end

    if NSkin:GetSkinningElement(IDs.Spells.Icons) then
        NSkin:RefreshIconGroup(IDs.Spells.Icons)
    end
    if pagedSpells then
        RefreshSpellNameAppearance(pagedSpells)
        RefreshSpellSecondaryTextAppearance(pagedSpells)
    end
    SkinSpellBookControls()
end


function SpellBookSkin:RefreshHeaders()
    if not NSkin:IsModuleEnabled("SpellBook") then return end
    local playerSpells = _G.PlayerSpellsFrame
    local spellBook = playerSpells and playerSpells.SpellBookFrame
    local pagedSpells = spellBook and spellBook.PagedSpellsFrame
    if not pagedSpells or not pagedSpells.EnumerateFrames then return end
    for _, frame in pagedSpells:EnumerateFrames() do
        if not (frame.HasValidData and frame:HasValidData()) and frame.Text then
            SkinSpellBookHeader(frame)
        end
    end
    NSkin:NotifySkinningElementBoundsChanged(IDs.Headers)
end


function SpellBookSkin:ApplyIconDisposition()
    if not NSkin:IsModuleEnabled("SpellBook") then return false end
    return iconDisposition and iconDisposition:Apply() or false
end

local function RemoveSpellBookBackground()
    local playerSpells = _G.PlayerSpellsFrame
    local spellBook = playerSpells and playerSpells.SpellBookFrame
    if not spellBook then return end

    if playerSpells.Bg then playerSpells.Bg:SetAlpha(0) end
    if playerSpells.TopTileStreaks then
        playerSpells.TopTileStreaks:SetTexture(nil)
        playerSpells.TopTileStreaks:Hide()
    end

    -- These belong to the inherited panel template rather than the spellbook
    -- artwork. Its top edge is the faint curved streak left below the title.
    local inset = playerSpells.Inset
    if inset then
        if inset.Bg then
            inset.Bg:SetTexture(nil)
            inset.Bg:Hide()
        end
        if inset.NineSlice then inset.NineSlice:Hide() end
    end

    local regions = {
        spellBook.TopBar,
        spellBook.BookBGHalved,
        spellBook.BookBGLeft,
        spellBook.BookBGRight,
        spellBook.Bookmark,
        spellBook.BookCornerFlipbook,
    }

    for i = 1, #regions do
        local region = regions[i]
        if region then region:SetAlpha(0) end
    end

    local pagedSpells = spellBook.PagedSpellsFrame
    RegisterSpellBookContentFamilies(playerSpells, spellBook)
    local pagingControls = pagedSpells and pagedSpells.PagingControls
    if pagingControls and pagingControls.PageText then
        pagingControls.PageText:SetTextColor(unpack(NSkin:GetStyle("button").text))
    end
end

function SpellBookSkin:Initialize()
    if State.initialized then return true end
    if not NSkin:IsModuleEnabled("SpellBook") then return false end

    local mixin = _G.SpellBookItemMixin
    local playerSpells = _G.PlayerSpellsFrame
    local spellBook = playerSpells and playerSpells.SpellBookFrame
    if not mixin or type(mixin.UpdateVisuals) ~= "function" or not _G.hooksecurefunc
        or not spellBook
    then
        return false
    end

    _G.hooksecurefunc(mixin, "UpdateVisuals", SkinSpellBookItem)
    -- Blizzard restores the backplate alpha on both hover edges.
    if type(mixin.OnIconEnter) == "function" then
        _G.hooksecurefunc(mixin, "OnIconEnter", SkinSpellBookItem)
    end
    if type(mixin.OnIconLeave) == "function" then
        _G.hooksecurefunc(mixin, "OnIconLeave", SkinSpellBookItem)
    end

    if type(playerSpells.UpdateTabs) == "function" then
        _G.hooksecurefunc(playerSpells, "UpdateTabs", SkinSpellBookTabs)
    end
    if type(spellBook.UpdateAllSpellData) == "function" then
        _G.hooksecurefunc(spellBook, "UpdateAllSpellData", SkinSpellBookTabs)
    end

    NSkin:RegisterTabGroup(IDs.MainTabs, {
        label = "Spellbook tabs",
        kind = "TAB_GROUP",
        module = "SpellBook",
        appearanceWindowID = IDs.AppearanceWindow,
        independentPlacement = true,
        movable = true,
        window = playerSpells,
        target = playerSpells.TabSystem,
        container = playerSpells.TabSystem,
        priority = 50,
        orientation = "HORIZONTAL",
        edge = "BOTTOM",
        hasPlacement = HasMainTabPlacement,
        getPlacement = GetMainTabPlacement,
        setPlacement = SetMainTabPlacement,
        resetPlacement = ResetMainTabPlacement,
    })
    local categoryTabSystem = spellBook.CategoryTabSystem
    if categoryTabSystem and not State.original.categoryTabPoints then
        State.original.categoryTabPoints = {}
        for i = 1, categoryTabSystem:GetNumPoints() do
            State.original.categoryTabPoints[i] = { categoryTabSystem:GetPoint(i) }
        end
    end
    NSkin:RegisterTabGroup(IDs.CategoryTabs, {
        label = "Spellbook class tabs",
        kind = "TAB_GROUP",
        module = "SpellBook",
        appearanceWindowID = IDs.AppearanceWindow,
        independentPlacement = true,
        movable = true,
        snapTarget = true,
        supportedEdges = { "TOP", "BOTTOM" },
        window = playerSpells,
        target = categoryTabSystem,
        container = categoryTabSystem,
        priority = 60,
        orientation = "HORIZONTAL",
        edge = "TOP",
        hasPlacement = HasCategoryTabPlacement,
        getPlacement = GetCategoryTabPlacement,
        setPlacement = SetCategoryTabPlacement,
        resetPlacement = ResetCategoryTabPlacement,
    })
    NSkin:RegisterSkinningElement(IDs.Window, {
        label = "Spellbook window",
        kind = "WINDOW",
        module = "SpellBook",
        appearanceWindowID = IDs.AppearanceWindow,
        window = playerSpells,
        target = playerSpells,
        priority = 0,
        extraEditorOptions = {
            { id = "spellbook.iconDisposition", label = "Spellbook",
                presentation = "INLINE", category = "SPECIFIC" },
        },
    })
    RegisterTalentControls(playerSpells)
    RegisterSpecializationControls(playerSpells)

    local pagedSpells = spellBook and spellBook.PagedSpellsFrame
    NSkin:RegisterSkinningElement(IDs.Headers, {
        label = "Spellbook class/spec headers",
        kind = "SECTION_HEADERS",
        module = "SpellBook",
        appearanceWindowID = IDs.AppearanceWindow,
        window = playerSpells,
        target = pagedSpells,
        priority = 70,
        draggable = false,
        refreshAppearance = function()
            SpellBookSkin:RefreshHeaders()
            return true
        end,
        refreshLayout = function()
            SpellBookSkin:RefreshHeaders()
            return true
        end,
        highlightRegions = function()
            local regions = {}
            if pagedSpells and pagedSpells.EnumerateFrames then
                for _, frame in pagedSpells:EnumerateFrames() do
                    if not (frame.HasValidData and frame:HasValidData()) and frame.Text then
                        regions[#regions + 1] = frame.Text
                        local line = NSkin:GetSectionHeaderUnderline(frame)
                        if line then regions[#regions + 1] = line end
                    end
                end
            end
            return regions
        end,
        isEditable = function()
            if not pagedSpells or not pagedSpells.EnumerateFrames then return false end
            for _, frame in pagedSpells:EnumerateFrames() do
                if not (frame.HasValidData and frame:HasValidData()) and frame.Text then
                    return true
                end
            end
            return false
        end,
        getSectionHeaderOffset = function() return NSkin:GetSpellBookHeaderOffset() end,
        setSectionHeaderOffset = function(_, x, y)
            return NSkin:SetSpellBookHeaderOffset(x, y)
        end,
        resetSectionHeaderOffset = function()
            return NSkin:SetSpellBookHeaderOffset(0, 0)
        end,
    })
    local pagingControls = pagedSpells and pagedSpells.PagingControls
    local defaultCog = { edge = "TOP", side = "INSIDE", alignment = "RIGHT",
        alongOffset = -30, edgeOffset = -17 }
    local defaultSearch = { edge = "TOP", side = "INSIDE", alignment = "RIGHT",
        alongOffset = -35 - (spellBook.SettingsDropdown:GetWidth() or 0), edgeOffset = -17 }
    local defaultBottom = { edge = "BOTTOM", side = "INSIDE", alignment = "RIGHT",
        alongOffset = -20, edgeOffset = 20 }
    State.searchController = NSkin:RegisterAccessoryGroup({
        module = "SpellBook", appearanceWindowID = IDs.AppearanceWindow,
        window = playerSpells,
        ids = { primary = IDs.Search.Group, accessory = IDs.Search.Accessory },
        primary = spellBook.SearchBox, accessory = spellBook.SettingsDropdown,
        primaryLabel = "Spellbook search", accessoryLabel = "Spellbook search cog",
        primaryPlacement = defaultSearch, accessoryPlacement = defaultCog,
        legacyOptionKey = "searchCogMode", snapTarget = true,
        visibilityFrame = spellBook,
        anchorGrouped = function(searchBox, cog)
            cog:ClearAllPoints()
            cog:SetPoint("LEFT", searchBox, "RIGHT", 5, 0)
            return true
        end,
    })
    State.paginationController = NSkin:RegisterPaginationGroup({
        module = "SpellBook", appearanceWindowID = IDs.AppearanceWindow,
        window = playerSpells,
        ids = { group = IDs.Pagination.Group, previous = IDs.Pagination.Previous,
            next = IDs.Pagination.Next, text = IDs.Pagination.Text },
        controls = { group = pagingControls,
            previous = pagingControls and pagingControls.PrevPageButton,
            next = pagingControls and pagingControls.NextPageButton,
            text = pagingControls and pagingControls.PageText },
        groupLabel = "Spellbook pagination", defaultPlacement = defaultBottom,
        legacySeparateOptionKey = "separatePaginationButtons",
        legacyTextOptionKey = "paginationTextMode",
        visibilityFrame = spellBook,
    })
    local pagedContentMixin = _G.PagedContentFrameBaseMixin
    local pagedContentEvent = pagedContentMixin and pagedContentMixin.Event
        and pagedContentMixin.Event.OnUpdate
    if pagedSpells and pagedContentEvent and type(pagedSpells.RegisterCallback) == "function" then
        -- Runs after the pool has released, acquired, and initialized every
        -- frame for the newly displayed page.
        pagedSpells:RegisterCallback(pagedContentEvent, SkinActiveSpellBookItems, SpellBookSkin)
    end

    RemoveSpellBookBackground()
    self:ApplyIconDisposition()
    SkinActiveSpellBookItems()
    State.initialized = true
    return true
end

function SpellBookSkin:RefreshAppearance()
    if State.initialized then
        SkinSpellBookControls()
        RegisterTalentControls(_G.PlayerSpellsFrame)
        RegisterSpecializationControls(_G.PlayerSpellsFrame)
        local playerSpells = _G.PlayerSpellsFrame
        if playerSpells and playerSpells.SpellBookFrame then
            RegisterSpellBookContentFamilies(
                playerSpells, playerSpells.SpellBookFrame)
        end
        SkinActiveSpellBookItems()
        NSkin:ApplyTabGroupLayout(IDs.MainTabs)
        NSkin:ApplyTabGroupLayout(IDs.CategoryTabs)
    end
end

NSkin:RegisterWindowSkin({
    module = "SpellBook",
    addon = "Blizzard_PlayerSpells",
    apply = function() return SpellBookSkin:Initialize() end,
})
