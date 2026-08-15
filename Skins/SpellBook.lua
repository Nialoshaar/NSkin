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

local function HideTextureRegions(frame, textureToKeep)
    if not frame or not frame.GetRegions then return end

    for region in frame.regionIterator or frame:GetRegions() do
        if region ~= textureToKeep and region.GetObjectType
            and region:GetObjectType() == "Texture" then
            region:SetTexture(nil)
            region:Hide()
        end
    end
end

local function CreateFlatBackground(frame, color)
    if frame.NSkinFlatBackground then return frame.NSkinFlatBackground end

    local background = frame:CreateTexture(nil, "BACKGROUND", nil, 7)
    background:SetPoint("TOPLEFT", 1, -1)
    background:SetPoint("BOTTOMRIGHT", -1, 1)
    background:SetColorTexture(unpack(color or CONTROL_BACKGROUND))
    frame.NSkinFlatBackground = background
    NSkin:CreatePixelBorder(frame, "NSkinFlatBorder", BORDER_SIZE, DIVIDER_COLOR)
    return background
end

local function SkinFlatButton(button, label)
    if not button then return end

    button:SetNormalTexture(nil)
    button:SetPushedTexture(nil)
    button:SetDisabledTexture(nil)
    button:SetHighlightTexture(nil)
    CreateFlatBackground(button)

    if label and not button.NSkinLabel then
        local text = button:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        text:SetPoint("CENTER", 0, 1)
        text:SetText(label)
        button.NSkinLabel = text
    end
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
end

local function RemoveSpellBookBackground()
    local playerSpells = _G.PlayerSpellsFrame
    local spellBook = playerSpells and playerSpells.SpellBookFrame
    if not spellBook then return end

    if playerSpells.Bg then playerSpells.Bg:SetAlpha(0) end

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
    SkinActiveSpellBookItems()
end

if _G.C_AddOns and _G.C_AddOns.IsAddOnLoaded("Blizzard_PlayerSpells") then
    SpellBookSkin:Initialize()
elseif _G.EventUtil and _G.EventUtil.ContinueOnAddOnLoaded then
    _G.EventUtil.ContinueOnAddOnLoaded("Blizzard_PlayerSpells", function()
        SpellBookSkin:Initialize()
    end)
end
