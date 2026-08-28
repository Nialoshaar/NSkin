local _, NSkin = ...

local SpellBookSkin = NSkin:NewModule("SpellBook")

local BORDER_SIZE = 1
local CIRCLE_MASK_ATLAS = "talents-node-circle-mask"
local ICON_SIZE = 50
local ICON_CROP = 0.06
local PAGING_BUTTON_TEXT_SIZE = 16
local SPELL_BOOK_BORDER_KEY = "NSkinSpellBookItemBorder"
local SPELL_BOOK_STATE = "spellBook"
local WINDOW_BUTTON_TEXT_SIZE = 20
local WINDOW_BUTTON_TEXT_OFFSET_X = 0
local WINDOW_BUTTON_TEXT_OFFSET_Y = 0

local assistedCombatDivider
local initialized = false
local bottomTabLayout = { edge = "BOTTOM" }
local TAB_GROUP_ID = "SpellBook.MainTabs"
local CATEGORY_TAB_GROUP_ID = "SpellBook.CategoryTabs"
local WINDOW_ELEMENT_ID = "SpellBook.Window"
local SEARCH_ELEMENT_ID = "SpellBook.Search"
local SEARCH_COG_ELEMENT_ID = "SpellBook.Search.Cog"
local PAGINATION_ELEMENT_ID = "SpellBook.Pagination"
local PREVIOUS_ELEMENT_ID = "SpellBook.Pagination.Previous"
local NEXT_ELEMENT_ID = "SpellBook.Pagination.Next"
local PAGE_TEXT_ELEMENT_ID = "SpellBook.Pagination.Text"
local spellBookPaginationController
local spellBookSearchController
local RestoreCategoryTabAnchors
local categoryTabOriginalPoints
local CATEGORY_TAB_DEFAULT = {
    edge = "TOP",
    side = "INSIDE",
    alignment = "LEFT",
    alongOffset = 0,
    edgeOffset = 0,
}

local function RoundOne(value)
    value = tonumber(value) or 0
    if value >= 0 then return math.floor(value * 10 + 0.5) / 10 end
    return math.ceil(value * 10 - 0.5) / 10
end

function NSkin:GetSpellBookTextSize()
    local defaults = self.defaultModuleOptions.SpellBook
    local options = self:GetModuleOptions("SpellBook", false)
    local size = options and tonumber(options.textSize)
    if not size then return defaults.textSize end
    return math.max(defaults.minTextSize,
        math.min(defaults.maxTextSize, math.floor(size + 0.5)))
end

function NSkin:SetSpellBookTextSize(size)
    size = tonumber(size)
    if not size then return false end

    local defaults = self.defaultModuleOptions.SpellBook
    size = math.max(defaults.minTextSize,
        math.min(defaults.maxTextSize, math.floor(size + 0.5)))
    if size == defaults.textSize then
        local options = self:GetModuleOptions("SpellBook", false)
        if options then
            options.textSize = nil
            local profile = self:GetProfile()
            if not next(options) then profile.moduleOptions.SpellBook = nil end
            if not next(profile.moduleOptions) then profile.moduleOptions = nil end
        end
    else
        self:GetModuleOptions("SpellBook", true).textSize = size
    end

    if self:IsModuleEnabled("SpellBook") and SpellBookSkin.RefreshTextSize then
        SpellBookSkin:RefreshTextSize()
    end
    return true
end

function NSkin:GetSpellBookAssistantHidden()
    local options = self:GetModuleOptions("SpellBook", false)
    return options and options.hideAssistant == true or false
end

function NSkin:SetSpellBookAssistantHidden(hidden)
    if _G.InCombatLockdown and _G.InCombatLockdown() then return false end
    hidden = hidden == true
    local options = self:GetModuleOptions("SpellBook", hidden)
    if hidden then
        options.hideAssistant = true
    elseif options then
        options.hideAssistant = nil
        local profile = self:GetProfile()
        if not next(options) then profile.moduleOptions.SpellBook = nil end
        if profile.moduleOptions and not next(profile.moduleOptions) then
            profile.moduleOptions = nil
        end
    end
    if self:IsModuleEnabled("SpellBook") and SpellBookSkin.RefreshAssistant then
        SpellBookSkin:RefreshAssistant()
    end
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

local function GetMainTabPlacement()
    return CopyPlacement(GetMainTabPlacementOptions() or NSkin:GetTabPlacement())
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
    NSkin:ApplyTabGroupLayout(TAB_GROUP_ID)
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
    return NSkin:ApplyTabGroupLayout(TAB_GROUP_ID)
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
    local category = self:GetTabGroup(CATEGORY_TAB_GROUP_ID)
    if category then RestoreCategoryTabAnchors(category.container) end
    self:ApplyTabGroupLayout(TAB_GROUP_ID)
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
    return CopyPlacement(GetCategoryTabPlacementOptions() or CATEGORY_TAB_DEFAULT)
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
        NSkin:ApplyTabGroupLayout(CATEGORY_TAB_GROUP_ID)
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
    NSkin:ApplyTabGroupLayout(CATEGORY_TAB_GROUP_ID)
    return true
end

RestoreCategoryTabAnchors = function(tabSystem)
    if not tabSystem or not categoryTabOriginalPoints
        or (_G.InCombatLockdown and _G.InCombatLockdown())
    then
        return false
    end
    tabSystem:ClearAllPoints()
    for i = 1, #categoryTabOriginalPoints do
        tabSystem:SetPoint(unpack(categoryTabOriginalPoints[i]))
    end
    if tabSystem.MarkDirty then tabSystem:MarkDirty() end
    NSkin:NotifySkinningElementBoundsChanged(CATEGORY_TAB_GROUP_ID)
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
    return RestoreCategoryTabAnchors(group.container)
end

local function SetFontSize(fontString, size)
    if not fontString or not size then return end

    local font, _, flags = fontString:GetFont()
    if font then fontString:SetFont(font, size, flags) end
end

local function SkinSpellBookTabs()
    local playerSpells = _G.PlayerSpellsFrame
    local spellBook = playerSpells and playerSpells.SpellBookFrame
    if not spellBook then return end

    local style = NSkin:GetStyle("tab")
    NSkin:SkinTabSystem(spellBook.CategoryTabSystem, style)
    NSkin:LayoutTabSystem(spellBook.CategoryTabSystem)
    if NSkin:GetTabGroup(CATEGORY_TAB_GROUP_ID) then
        NSkin:ApplyTabGroupLayout(CATEGORY_TAB_GROUP_ID)
    end
    NSkin:SkinTabSystem(playerSpells.TabSystem, style)
    if NSkin:GetTabGroup(TAB_GROUP_ID) then
        NSkin:ApplyTabGroupLayout(TAB_GROUP_ID)
    else
        bottomTabLayout.owner = playerSpells
        NSkin:LayoutTabSystem(playerSpells.TabSystem, bottomTabLayout)
    end
end

local function SkinWindowButtons(playerSpells, spellBook)
    if not playerSpells or not spellBook then return end

    local closeButton = playerSpells.CloseButton
    local expandFrame = playerSpells.MaximizeMinimizeButton
    local maximizeButton = expandFrame and expandFrame.MaximizeButton
    local minimizeButton = expandFrame and expandFrame.MinimizeButton

    NSkin:SkinFlatButton(closeButton, "x", nil, nil,
        WINDOW_BUTTON_TEXT_SIZE, WINDOW_BUTTON_TEXT_OFFSET_X, WINDOW_BUTTON_TEXT_OFFSET_Y)
    NSkin:SkinFlatButton(maximizeButton, "+", nil, nil,
        WINDOW_BUTTON_TEXT_SIZE, WINDOW_BUTTON_TEXT_OFFSET_X, WINDOW_BUTTON_TEXT_OFFSET_Y)
    NSkin:SkinFlatButton(minimizeButton, "-", nil, nil,
        WINDOW_BUTTON_TEXT_SIZE, WINDOW_BUTTON_TEXT_OFFSET_X, WINDOW_BUTTON_TEXT_OFFSET_Y)

    if closeButton then
        closeButton:SetSize(22, 22)
        closeButton:ClearAllPoints()
        closeButton:SetPoint("TOPRIGHT", playerSpells, "TOPRIGHT", 0, 0)
    end
    if expandFrame and closeButton then
        expandFrame:SetSize(22, 22)
        expandFrame:ClearAllPoints()
        expandFrame:SetPoint("BOTTOMRIGHT", closeButton, "BOTTOMLEFT", 0, 0)
    end
end

local function SkinAssistedCombat(frame)
    if not frame then return end

    local data = NSkin:GetSkinData(frame, SPELL_BOOK_STATE)
    if not data.spellBookSkinned then
        NSkin:HideTextureRegions(frame)
        data.spellBookSkinned = true
    end
    if frame.Label then frame.Label:SetTextColor(unpack(NSkin:GetStyle("button").text)) end

    local button = frame.Button
    local icon = button and button.Icon
    if button and icon then
        if button.Border then
            button.Border:SetTexture(nil)
            button.Border:Hide()
        end
        local border = NSkin:CreatePixelBorder(button, "NSkinSpellBookBorder", BORDER_SIZE,
            NSkin:GetStyle("icon").border, false, icon)
        NSkin:SetPixelBorderColor(border, unpack(NSkin:GetStyle("icon").border))
    end

    if not assistedCombatDivider then
        assistedCombatDivider = frame:CreateTexture(nil, "ARTWORK", nil, 1)
        assistedCombatDivider:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -2)
        assistedCombatDivider:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 2)
        assistedCombatDivider:SetWidth(1)
    end
    assistedCombatDivider:SetColorTexture(unpack(NSkin:GetStyle("window").header.divider))
    local hidden = NSkin:GetSpellBookAssistantHidden()
    local assistantIcon = frame.Button and frame.Button.Icon
    local assistantBorder = frame.Button
        and NSkin:GetPixelBorder(frame.Button, "NSkinSpellBookBorder")
    if hidden then
        if not data.assistantHiddenByNSkin then
            data.assistantWasShown = frame:IsShown()
            data.assistantAlpha = frame:GetAlpha()
            data.assistantMouseEnabled = frame:IsMouseEnabled()
            data.assistantButtonWasShown = frame.Button and frame.Button:IsShown()
        end
        if frame.Label then frame.Label:Hide() end
        if assistantIcon then assistantIcon:Hide() end
        if assistantBorder then NSkin:SetPixelBorderShown(assistantBorder, false) end
        assistedCombatDivider:Hide()
        if frame.Button then frame.Button:Hide() end
        frame:EnableMouse(false)
        frame:SetAlpha(0)
        frame:Hide()
        data.assistantHiddenByNSkin = true
    elseif data.assistantHiddenByNSkin then
        if frame.Label then frame.Label:Show() end
        if assistantIcon then assistantIcon:Show() end
        if assistantBorder then NSkin:SetPixelBorderShown(assistantBorder, true) end
        assistedCombatDivider:Show()
        frame:SetAlpha(data.assistantAlpha or 1)
        frame:EnableMouse(data.assistantMouseEnabled == true)
        if frame.Button and data.assistantButtonWasShown then frame.Button:Show() end
        if data.assistantWasShown then frame:Show() end
        data.assistantWasShown = nil
        data.assistantAlpha = nil
        data.assistantMouseEnabled = nil
        data.assistantButtonWasShown = nil
        data.assistantHiddenByNSkin = nil
    end
end

local function SkinTitleBar(playerSpells, spellBook)
    if not playerSpells or not spellBook then return end

    if playerSpells.NineSlice then playerSpells.NineSlice:Hide() end
    NSkin:SkinWindow(playerSpells)
    if playerSpells.TitleContainer and playerSpells.TitleContainer.TitleText then
        playerSpells.TitleContainer.TitleText:SetTextColor(unpack(NSkin:GetStyle("button").text))
    end

    NSkin:SkinWindowHeader(playerSpells)
end

local function RemoveSpellBookPortraitAndHelp(playerSpells, spellBook)
    if not playerSpells or not spellBook then return end

    if playerSpells.PortraitContainer then
        playerSpells.PortraitContainer:SetAlpha(0)
        playerSpells.PortraitContainer:Hide()
    elseif playerSpells.portrait then
        playerSpells.portrait:SetAlpha(0)
        playerSpells.portrait:Hide()
    end

    if spellBook.HelpPlateButton then
        spellBook.HelpPlateButton:SetAlpha(0)
        spellBook.HelpPlateButton:Hide()
    end
end

local function SkinSpellBookControls()
    local playerSpells = _G.PlayerSpellsFrame
    local spellBook = playerSpells and playerSpells.SpellBookFrame
    local pagedSpells = spellBook and spellBook.PagedSpellsFrame
    if not spellBook then return end
    if spellBookPaginationController then spellBookPaginationController:Refresh() end

    RemoveSpellBookPortraitAndHelp(playerSpells, spellBook)
    SkinTitleBar(playerSpells, spellBook)
    SkinSpellBookTabs()
    NSkin:SkinSearchBox(spellBook.SearchBox)
    NSkin:SkinPagingControls(pagedSpells and pagedSpells.PagingControls,
        PAGING_BUTTON_TEXT_SIZE)
    SkinAssistedCombat(spellBook.AssistedCombatRotationSpellFrame)
    SkinWindowButtons(playerSpells, spellBook)
end

local function CreateCircularBorder(button, icon)
    local border = button:CreateTexture(nil, "ARTWORK", nil, -2)
    border:SetColorTexture(unpack(NSkin:GetStyle("icon").border))
    border:SetPoint("TOPLEFT", icon, "TOPLEFT", -BORDER_SIZE, BORDER_SIZE)
    border:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", BORDER_SIZE, -BORDER_SIZE)

    local mask = button:CreateMaskTexture(nil, "ARTWORK")
    mask:SetAtlas(CIRCLE_MASK_ATLAS, false)
    mask:SetAllPoints(border)
    border:AddMaskTexture(mask)

    border:Hide()
    NSkin:GetSkinData(button, SPELL_BOOK_STATE).circularBorder = border
    return border
end

local function SkinSpellBookItem(item)
    if not item or not item.Button then return end

    local button = item.Button
    local icon = button.Icon
    if not icon then return end

    icon:SetSize(ICON_SIZE, ICON_SIZE)
    icon:SetTexCoord(ICON_CROP, 1 - ICON_CROP, ICON_CROP, 1 - ICON_CROP)

    local spellInfo = item.spellBookItemInfo
    local isPassive = spellInfo and spellInfo.isPassive

    -- Keep functional overlays while removing Blizzard's ornamental artwork.
    if item.Backplate then item.Backplate:SetAlpha(0) end
    local textColor = NSkin:GetStyle("button").text
    if item.Name then
        item.Name:SetTextColor(unpack(textColor))
        SetFontSize(item.Name, NSkin:GetSpellBookTextSize())
    end
    if item.SubName then item.SubName:SetTextColor(unpack(textColor)) end
    if item.RequiredLevel then item.RequiredLevel:SetTextColor(unpack(textColor)) end
    if button.BorderSheen then button.BorderSheen:SetAlpha(0) end
    if button.Border then
        button.Border:SetTexture(nil)
        button.Border:Hide()
    end

    local border = NSkin:GetPixelBorder(button, SPELL_BOOK_BORDER_KEY)
    if not border then
        border = NSkin:CreatePixelBorder(
            button,
            SPELL_BOOK_BORDER_KEY,
            BORDER_SIZE,
            NSkin:GetStyle("icon").border,
            false,
            icon
        )
    end
    NSkin:SetPixelBorderColor(border, unpack(NSkin:GetStyle("icon").border))

    local data = NSkin:GetSkinData(button, SPELL_BOOK_STATE)
    local circularBorder = data.circularBorder

    if isPassive then
        NSkin:SetPixelBorderShown(border, false)
        if button.IconMask then button.IconMask:Show() end

        circularBorder = circularBorder or CreateCircularBorder(button, icon)
        circularBorder:SetColorTexture(unpack(NSkin:GetStyle("icon").border))
        circularBorder:Show()
    else
        NSkin:SetPixelBorderShown(border, true)
        if button.IconMask then button.IconMask:Hide() end
        if circularBorder then circularBorder:Hide() end
    end
end

local function SkinSpellBookHeader(header)
    if not header then return end

    if header.Backplate then
        header.Backplate:SetTexture(nil)
        header.Backplate:Hide()
    end
    if header.Text then header.Text:SetTextColor(unpack(NSkin:GetStyle("button").text)) end
    if header.Border then
        header.Border:SetTexture(nil)
        header.Border:Hide()
    end

    local data = NSkin:GetSkinData(header, SPELL_BOOK_STATE)
    if not data.headerLine then
        local line = header:CreateTexture(nil, "ARTWORK", nil, 1)
        line:SetPoint("BOTTOMLEFT", header, "BOTTOMLEFT", -8, 12)
        line:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT", -60, 12)
        line:SetHeight(1)
        data.headerLine = line
    end
    data.headerLine:SetColorTexture(unpack(NSkin:GetStyle("window").header.divider))
end

local function RemoveActionBarDecoration(item)
    local button = item and item.Button
    local highlight = button and button.ActionBarHighlight
    if not highlight then return end

    if highlight.Anim and highlight.Anim:IsPlaying() then
        highlight.Anim:Stop()
    end
    highlight:Hide()
end

local function SkinActiveSpellBookItems()
    local playerSpells = _G.PlayerSpellsFrame
    local spellBook = playerSpells and playerSpells.SpellBookFrame
    local pagedSpells = spellBook and spellBook.PagedSpellsFrame
    if pagedSpells and pagedSpells.EnumerateFrames then
        for _, frame in pagedSpells:EnumerateFrames() do
            if frame.HasValidData and frame:HasValidData() then
                SkinSpellBookItem(frame)
                RemoveActionBarDecoration(frame)
            elseif frame.Text then
                SkinSpellBookHeader(frame)
            end
        end
    end

    SkinSpellBookControls()
end

function SpellBookSkin:RefreshTextSize()
    if not NSkin:IsModuleEnabled("SpellBook") then return end

    local playerSpells = _G.PlayerSpellsFrame
    local spellBook = playerSpells and playerSpells.SpellBookFrame
    local pagedSpells = spellBook and spellBook.PagedSpellsFrame
    if not pagedSpells or not pagedSpells.EnumerateFrames then return end

    local size = NSkin:GetSpellBookTextSize()
    for _, frame in pagedSpells:EnumerateFrames() do
        if frame.HasValidData and frame:HasValidData() and frame.Name then
            SetFontSize(frame.Name, size)
        end
    end
end

function SpellBookSkin:RefreshAssistant()
    if not NSkin:IsModuleEnabled("SpellBook") then return end
    local playerSpells = _G.PlayerSpellsFrame
    local spellBook = playerSpells and playerSpells.SpellBookFrame
    local frame = spellBook and spellBook.AssistedCombatRotationSpellFrame
    if frame then SkinAssistedCombat(frame) end
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
    local pagingControls = pagedSpells and pagedSpells.PagingControls
    if pagingControls and pagingControls.PageText then
        pagingControls.PageText:SetTextColor(unpack(NSkin:GetStyle("button").text))
    end
end

function SpellBookSkin:Initialize()
    if initialized then return true end
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
    if type(mixin.UpdateActionBarAnim) == "function" then
        _G.hooksecurefunc(mixin, "UpdateActionBarAnim", RemoveActionBarDecoration)
    end

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

    NSkin:RegisterTabGroup(TAB_GROUP_ID, {
        label = "Spellbook tabs",
        kind = "TAB_GROUP",
        editorOptions = "tabs.layout",
        independentPlacement = true,
        movable = true,
        window = playerSpells,
        target = playerSpells.TabSystem,
        container = playerSpells.TabSystem,
        priority = 50,
        orientation = "HORIZONTAL",
        edge = "BOTTOM",
        getPlacement = GetMainTabPlacement,
        setPlacement = SetMainTabPlacement,
        resetPlacement = ResetMainTabPlacement,
    })
    local categoryTabSystem = spellBook.CategoryTabSystem
    if categoryTabSystem and not categoryTabOriginalPoints then
        categoryTabOriginalPoints = {}
        for i = 1, categoryTabSystem:GetNumPoints() do
            categoryTabOriginalPoints[i] = { categoryTabSystem:GetPoint(i) }
        end
    end
    NSkin:RegisterTabGroup(CATEGORY_TAB_GROUP_ID, {
        label = "Spellbook class tabs",
        kind = "TAB_GROUP",
        editorOptions = "tabs.layout",
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
    NSkin:RegisterSkinningElement(WINDOW_ELEMENT_ID, {
        label = "Spellbook window",
        kind = "WINDOW",
        editorOptions = "spellbook.window",
        window = playerSpells,
        target = playerSpells,
        priority = 0,
    })

    local pagedSpells = spellBook and spellBook.PagedSpellsFrame
    local pagingControls = pagedSpells and pagedSpells.PagingControls
    local defaultCog = { edge = "TOP", side = "INSIDE", alignment = "RIGHT",
        alongOffset = -30, edgeOffset = -17 }
    local defaultSearch = { edge = "TOP", side = "INSIDE", alignment = "RIGHT",
        alongOffset = -35 - (spellBook.SettingsDropdown:GetWidth() or 0), edgeOffset = -17 }
    local defaultBottom = { edge = "BOTTOM", side = "INSIDE", alignment = "RIGHT",
        alongOffset = -20, edgeOffset = 20 }
    spellBookSearchController = NSkin:RegisterAccessoryGroup({
        module = "SpellBook", window = playerSpells,
        ids = { primary = SEARCH_ELEMENT_ID, accessory = SEARCH_COG_ELEMENT_ID },
        primary = spellBook.SearchBox, accessory = spellBook.SettingsDropdown,
        primaryLabel = "Spellbook search", accessoryLabel = "Spellbook search cog",
        primaryPlacement = defaultSearch, accessoryPlacement = defaultCog,
        optionKey = "searchCogMode", snapTarget = true,
        visibilityFrame = spellBook,
        anchorGrouped = function(searchBox, cog)
            cog:ClearAllPoints()
            cog:SetPoint("LEFT", searchBox, "RIGHT", 5, 0)
            return true
        end,
    })
    spellBookPaginationController = NSkin:RegisterPaginationGroup({
        module = "SpellBook", window = playerSpells,
        ids = { group = PAGINATION_ELEMENT_ID, previous = PREVIOUS_ELEMENT_ID,
            next = NEXT_ELEMENT_ID, text = PAGE_TEXT_ELEMENT_ID },
        controls = { group = pagingControls,
            previous = pagingControls and pagingControls.PrevPageButton,
            next = pagingControls and pagingControls.NextPageButton,
            text = pagingControls and pagingControls.PageText },
        groupLabel = "Spellbook pagination", defaultPlacement = defaultBottom,
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
    SkinActiveSpellBookItems()
    initialized = true
    return true
end

function SpellBookSkin:RefreshTheme()
    if initialized then
        SkinSpellBookControls()
        SkinActiveSpellBookItems()
        NSkin:ApplyTabGroupLayout(TAB_GROUP_ID)
        NSkin:ApplyTabGroupLayout(CATEGORY_TAB_GROUP_ID)
    end
end

NSkin:RegisterWindowSkin({
    module = "SpellBook",
    addon = "Blizzard_PlayerSpells",
    apply = function() return SpellBookSkin:Initialize() end,
})
