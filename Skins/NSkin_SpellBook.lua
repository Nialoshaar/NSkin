local _, NSkin = ...

local SpellBookSkin = NSkin:NewModule("SpellBook")

local BORDER_SIZE = 1
local CIRCLE_MASK_ATLAS = "talents-node-circle-mask"
local ICON_SIZE = 50
local ICON_CROP = 0.06
local PAGING_BUTTON_TEXT_SIZE = 16
local WINDOW_BUTTON_TEXT_SIZE = 20
local WINDOW_BUTTON_TEXT_OFFSET_X = 0
local WINDOW_BUTTON_TEXT_OFFSET_Y = 0

local borders = setmetatable({}, { __mode = "k" })
local circularBorders = setmetatable({}, { __mode = "k" })
local headerLines = setmetatable({}, { __mode = "k" })
local assistedCombatDivider
local initialized = false

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
    NSkin:SkinTabSystem(playerSpells.TabSystem, style)
end

local function SkinSearchBox(searchBox)
    if not searchBox then return end

    local searchIcon = searchBox.SearchIcon or searchBox.searchIcon
    local data = NSkin:GetSkinData(searchBox)
    if not data.flatBackground then
        NSkin:HideTextureRegions(searchBox, searchIcon)
    end
    local style = NSkin:GetStyle("searchBox")
    data.flatBackground = NSkin:CreateFlatBackground(
        searchBox, nil, style.background, style.border
    )
    searchBox:SetTextColor(unpack(style.text))
    if searchBox.Instructions then
        searchBox.Instructions:SetTextColor(unpack(style.placeholderText))
    end
    if searchIcon then searchIcon:Show() end
end

local function SkinPagingControls(pagingControls)
    if not pagingControls then return end

    NSkin:SkinFlatButton(pagingControls.PrevPageButton, "<", nil, nil,
        PAGING_BUTTON_TEXT_SIZE)
    NSkin:SkinFlatButton(pagingControls.NextPageButton, ">", nil, nil,
        PAGING_BUTTON_TEXT_SIZE)
    if pagingControls.PageText then
        pagingControls.PageText:SetTextColor(unpack(NSkin:GetStyle("button").text))
    end

    local previous = pagingControls.PrevPageButton
    local nextPage = pagingControls.NextPageButton
    local previousData = previous and NSkin:GetSkinData(previous, false)
    local nextData = nextPage and NSkin:GetSkinData(nextPage, false)
    if previousData and previousData.label then
        previousData.label:SetAlpha(previous:IsEnabled() and 1 or 0.35)
    end
    if nextData and nextData.label then
        nextData.label:SetAlpha(nextPage:IsEnabled() and 1 or 0.35)
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
        closeButton:SetPoint("BOTTOMRIGHT", spellBook, "TOPRIGHT", 0, 0)
    end
    if expandFrame and closeButton then
        expandFrame:SetSize(22, 22)
        expandFrame:ClearAllPoints()
        expandFrame:SetPoint("BOTTOMRIGHT", closeButton, "BOTTOMLEFT", 0, 0)
    end
end

local function SkinAssistedCombat(frame)
    if not frame then return end

    local data = NSkin:GetSkinData(frame)
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
end

local function SkinTitleBar(playerSpells, spellBook)
    if not playerSpells or not spellBook then return end

    if playerSpells.NineSlice then playerSpells.NineSlice:Hide() end
    NSkin:SkinWindow(spellBook)
    if playerSpells.TitleContainer and playerSpells.TitleContainer.TitleText then
        playerSpells.TitleContainer.TitleText:SetTextColor(unpack(NSkin:GetStyle("button").text))
    end

    NSkin:SkinWindowHeader(playerSpells, spellBook)
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

    RemoveSpellBookPortraitAndHelp(playerSpells, spellBook)
    SkinTitleBar(playerSpells, spellBook)
    SkinSpellBookTabs()
    SkinSearchBox(spellBook.SearchBox)
    SkinPagingControls(pagedSpells and pagedSpells.PagingControls)
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

    if not borders[button] then
        borders[button] = NSkin:CreatePixelBorder(
            button,
            nil,
            BORDER_SIZE,
            NSkin:GetStyle("icon").border,
            false,
            icon
        )
    end
    NSkin:SetPixelBorderColor(borders[button], unpack(NSkin:GetStyle("icon").border))

    if isPassive then
        NSkin:SetPixelBorderShown(borders[button], false)
        if button.IconMask then button.IconMask:Show() end

        local circularBorder = circularBorders[button] or CreateCircularBorder(button, icon)
        circularBorder:SetColorTexture(unpack(NSkin:GetStyle("icon").border))
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
    if header.Text then header.Text:SetTextColor(unpack(NSkin:GetStyle("button").text)) end
    if header.Border then
        header.Border:SetTexture(nil)
        header.Border:Hide()
    end

    if not headerLines[header] then
        local line = header:CreateTexture(nil, "ARTWORK", nil, 1)
        line:SetPoint("BOTTOMLEFT", header, "BOTTOMLEFT", -8, 12)
        line:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT", -60, 12)
        line:SetHeight(1)
        headerLines[header] = line
    end
    headerLines[header]:SetColorTexture(unpack(NSkin:GetStyle("window").header.divider))
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
    if initialized then return end
    if not NSkin:IsModuleEnabled("SpellBook") then return end

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
    SkinActiveSpellBookItems()
end

function SpellBookSkin:RefreshTheme()
    if initialized then SkinActiveSpellBookItems() end
end

NSkin:RegisterWindowSkin({
    module = "SpellBook",
    addon = "Blizzard_PlayerSpells",
    apply = function() SpellBookSkin:Initialize() end,
})
