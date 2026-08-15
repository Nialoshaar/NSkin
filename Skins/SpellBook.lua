local _, NSkin = ...

local SpellBookSkin = NSkin:NewModule("SpellBook")

local BORDER_SIZE = 1
local CIRCLE_MASK_ATLAS = "talents-node-circle-mask"
local ICON_SIZE = 50
local ICON_CROP = 0.06
local CONTROL_BACKGROUND = { 0.04, 0.04, 0.04, 0.90 }
local CONTROL_BACKGROUND_SELECTED = { 0.16, 0.16, 0.16, 0.95 }
local DIVIDER_COLOR = { 0.45, 0.45, 0.45, 1 }

local borders = {}
local circularBorders = {}
local headerLines = {}
local spellBookBackground
local titleBarBackground
local assistedCombatDivider
local initialized = false

local function SkinCategoryTab(tab, selected)
    if not tab then return end

    if not tab.NSkinFlatBackground then
        if type(tab.SetTabSelected) == "function" and _G.hooksecurefunc then
            -- Keep the flat selected state synchronized for both the upper
            -- category tabs and the persistent bottom navigation tabs.
            _G.hooksecurefunc(tab, "SetTabSelected", SkinCategoryTab)
        end
        NSkin:HideTextureRegions(tab)
        NSkin:CreateFlatBackground(tab, nil, CONTROL_BACKGROUND, DIVIDER_COLOR)
        if tab.Text then tab.Text:SetTextColor(1, 1, 1) end
    end

    tab.NSkinFlatBackground:SetColorTexture(unpack(
        selected and CONTROL_BACKGROUND_SELECTED or CONTROL_BACKGROUND
    ))
end

local function SkinTabSystem(tabSystem)
    if not tabSystem or not tabSystem.tabs then return end

    for i = 1, #tabSystem.tabs do
        local tab = tabSystem.tabs[i]
        local selected = tab and tab.IsSelected and tab:IsSelected()
        SkinCategoryTab(tab, selected)
    end
end

local function SkinSpellBookTabs()
    local playerSpells = _G.PlayerSpellsFrame
    local spellBook = playerSpells and playerSpells.SpellBookFrame
    if not spellBook then return end

    SkinTabSystem(spellBook.CategoryTabSystem)
    SkinTabSystem(playerSpells.TabSystem)
end

local function SkinSearchBox(searchBox)
    if not searchBox then return end

    local searchIcon = searchBox.SearchIcon or searchBox.searchIcon
    if not searchBox.NSkinFlatBackground then
        NSkin:HideTextureRegions(searchBox, searchIcon)
        NSkin:CreateFlatBackground(searchBox, nil, { 0, 0, 0, 0.75 }, DIVIDER_COLOR)
    end
    searchBox:SetTextColor(1, 1, 1)
    if searchBox.Instructions then
        searchBox.Instructions:SetTextColor(0.55, 0.55, 0.55)
    end
    if searchIcon then searchIcon:Show() end
end

local function SkinPagingControls(pagingControls)
    if not pagingControls then return end

    NSkin:SkinFlatButton(pagingControls.PrevPageButton, "<", CONTROL_BACKGROUND, DIVIDER_COLOR)
    NSkin:SkinFlatButton(pagingControls.NextPageButton, ">", CONTROL_BACKGROUND, DIVIDER_COLOR)
    if pagingControls.PageText then
        pagingControls.PageText:SetTextColor(1, 1, 1)
    end

    local previous = pagingControls.PrevPageButton
    local nextPage = pagingControls.NextPageButton
    if previous and previous.NSkinLabel then
        previous.NSkinLabel:SetAlpha(previous:IsEnabled() and 1 or 0.35)
    end
    if nextPage and nextPage.NSkinLabel then
        nextPage.NSkinLabel:SetAlpha(nextPage:IsEnabled() and 1 or 0.35)
    end
end

local function SkinAssistedCombat(frame)
    if not frame then return end

    if not frame.NSkinSkinned then
        NSkin:HideTextureRegions(frame)
        frame.NSkinSkinned = true
    end
    if frame.Label then frame.Label:SetTextColor(1, 1, 1) end

    local button = frame.Button
    local icon = button and button.Icon
    if button and icon then
        if button.Border then
            button.Border:SetTexture(nil)
            button.Border:Hide()
        end
        NSkin:CreatePixelBorder(button, "NSkinSpellBookBorder", BORDER_SIZE,
            NSkin.colors.border, false, icon)
    end

    if not assistedCombatDivider then
        assistedCombatDivider = frame:CreateTexture(nil, "ARTWORK", nil, 1)
        assistedCombatDivider:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -2)
        assistedCombatDivider:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 2)
        assistedCombatDivider:SetWidth(1)
        assistedCombatDivider:SetColorTexture(unpack(DIVIDER_COLOR))
    end
end

local function SkinTitleBar(playerSpells, spellBook)
    if not playerSpells or not spellBook then return end

    if playerSpells.NineSlice then playerSpells.NineSlice:Hide() end
    if playerSpells.NSkinWindowBorder then
        NSkin:SetPixelBorderShown(playerSpells.NSkinWindowBorder, false)
    end
    NSkin:CreatePixelBorder(spellBook, "NSkinWindowBorder", BORDER_SIZE, DIVIDER_COLOR)
    if playerSpells.TitleContainer and playerSpells.TitleContainer.TitleText then
        playerSpells.TitleContainer.TitleText:SetTextColor(1, 1, 1)
    end

    if not titleBarBackground then
        titleBarBackground = playerSpells:CreateTexture(nil, "BACKGROUND", nil, 7)
        titleBarBackground:SetPoint("TOPLEFT", playerSpells, "TOPLEFT", 1, -1)
        titleBarBackground:SetPoint("TOPRIGHT", playerSpells, "TOPRIGHT", -1, -1)
        titleBarBackground:SetHeight(22)
        titleBarBackground:SetColorTexture(0.04, 0.04, 0.04, 0.95)
    end
end

local function SkinSpellBookControls()
    local playerSpells = _G.PlayerSpellsFrame
    local spellBook = playerSpells and playerSpells.SpellBookFrame
    local pagedSpells = spellBook and spellBook.PagedSpellsFrame
    if not spellBook then return end

    SkinTitleBar(playerSpells, spellBook)
    SkinSpellBookTabs()
    SkinSearchBox(spellBook.SearchBox)
    SkinPagingControls(pagedSpells and pagedSpells.PagingControls)
    SkinAssistedCombat(spellBook.AssistedCombatRotationSpellFrame)
end

local function CreateCircularBorder(button, icon)
    local border = button:CreateTexture(nil, "ARTWORK", nil, -2)
    border:SetColorTexture(unpack(NSkin.colors.border))
    border:SetPoint("TOPLEFT", icon, "TOPLEFT", -BORDER_SIZE, BORDER_SIZE)
    border:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", BORDER_SIZE, -BORDER_SIZE)

    local mask = button:CreateMaskTexture(nil, "ARTWORK")
    mask:SetAtlas(CIRCLE_MASK_ATLAS, false)
    mask:SetAllPoints(border)
    border:AddMaskTexture(mask)

    border:Hide()
    circularBorders[button] = border
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
    if item.Name then item.Name:SetTextColor(1, 1, 1) end
    if item.SubName then item.SubName:SetTextColor(1, 1, 1) end
    if item.RequiredLevel then item.RequiredLevel:SetTextColor(1, 1, 1) end
    if button.BorderSheen then button.BorderSheen:SetAlpha(0) end
    if button.Border then
        button.Border:SetTexture(nil)
        button.Border:Hide()
    end

    if not borders[button] then
        borders[button] = NSkin:CreatePixelBorder(
            button,
            nil,
            BORDER_SIZE,
            NSkin.colors.border,
            false,
            icon
        )
    end

    if isPassive then
        NSkin:SetPixelBorderShown(borders[button], false)
        if button.IconMask then button.IconMask:Show() end

        local circularBorder = circularBorders[button] or CreateCircularBorder(button, icon)
        circularBorder:Show()
    else
        NSkin:SetPixelBorderShown(borders[button], true)
        if button.IconMask then button.IconMask:Hide() end
        if circularBorders[button] then circularBorders[button]:Hide() end
    end
end

local function SkinSpellBookHeader(header)
    if not header then return end

    if header.Backplate then
        header.Backplate:SetTexture(nil)
        header.Backplate:Hide()
    end
    if header.Text then header.Text:SetTextColor(1, 1, 1) end
    if header.Border then
        header.Border:SetTexture(nil)
        header.Border:Hide()
    end

    if not headerLines[header] then
        local line = header:CreateTexture(nil, "ARTWORK", nil, 1)
        line:SetPoint("BOTTOMLEFT", header, "BOTTOMLEFT", -8, 12)
        line:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT", -60, 12)
        line:SetHeight(1)
        line:SetColorTexture(0.45, 0.45, 0.45, 1)
        headerLines[header] = line
    end
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
    if not pagedSpells or not pagedSpells.EnumerateFrames then return end

    for _, frame in pagedSpells:EnumerateFrames() do
        if frame.HasValidData and frame:HasValidData() then
            SkinSpellBookItem(frame)
            RemoveActionBarDecoration(frame)
        elseif frame.Text then
            SkinSpellBookHeader(frame)
        end
    end

    SkinSpellBookControls()
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

    if not spellBookBackground then
        spellBookBackground = spellBook:CreateTexture(nil, "BACKGROUND", nil, 0)
        spellBookBackground:SetAllPoints(spellBook)
        spellBookBackground:SetColorTexture(0, 0, 0, 0.80)
    end

    local pagedSpells = spellBook.PagedSpellsFrame
    local pagingControls = pagedSpells and pagedSpells.PagingControls
    if pagingControls and pagingControls.PageText then
        pagingControls.PageText:SetTextColor(1, 1, 1)
    end
end

function SpellBookSkin:Initialize()
    if initialized then return end

    local mixin = _G.SpellBookItemMixin
    if not mixin or type(mixin.UpdateVisuals) ~= "function" or not _G.hooksecurefunc then
        return
    end

    initialized = true
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

    local playerSpells = _G.PlayerSpellsFrame
    local spellBook = playerSpells and playerSpells.SpellBookFrame
    local pagedSpells = spellBook and spellBook.PagedSpellsFrame
    local pagedContentMixin = _G.PagedContentFrameBaseMixin
    local pagedContentEvent = pagedContentMixin and pagedContentMixin.Event
        and pagedContentMixin.Event.OnUpdate
    if pagedSpells and pagedContentEvent and type(pagedSpells.RegisterCallback) == "function" then
        -- Runs after the pool has released, acquired, and initialized every
        -- frame for the newly displayed page.
        pagedSpells:RegisterCallback(pagedContentEvent, SkinActiveSpellBookItems, SpellBookSkin)
    end

    RemoveSpellBookBackground()
    SkinSpellBookControls()
    SkinActiveSpellBookItems()
end

if _G.C_AddOns and _G.C_AddOns.IsAddOnLoaded("Blizzard_PlayerSpells") then
    SpellBookSkin:Initialize()
elseif _G.EventUtil and _G.EventUtil.ContinueOnAddOnLoaded then
    _G.EventUtil.ContinueOnAddOnLoaded("Blizzard_PlayerSpells", function()
        SpellBookSkin:Initialize()
    end)
end
