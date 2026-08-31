local _, NSkin = ...

local SpellBookSkin = NSkin:NewModule("SpellBook")

local BORDER_SIZE = 1
local CIRCLE_MASK_ATLAS = "talents-node-circle-mask"
local SPELL_BOOK_BORDER_KEY = "NSkinSpellBookItemBorder"
local SPELL_BOOK_STATE = "spellBook"
local WINDOW_BUTTON_TEXT_SIZE = 20
local WINDOW_BUTTON_TEXT_OFFSET_X = 0
local WINDOW_BUTTON_TEXT_OFFSET_Y = 0
local IDs = {
    AppearanceWindow = "PlayerSpells.SpellBook",
    Window = "SpellBook.Window",
    MainTabs = "SpellBook.MainTabs",
    CategoryTabs = "SpellBook.CategoryTabs",
    Headers = "SpellBook.Headers",
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
}
local Adapters = {}

NSkin:RegisterAppearanceScope(IDs.AppearanceWindow, { label = "Spellbook" })
local function RoundOne(value)
    value = tonumber(value) or 0
    if value >= 0 then return math.floor(value * 10 + 0.5) / 10 end
    return math.ceil(value * 10 - 0.5) / 10
end

function NSkin:GetSpellBookTextSizeOverride()
    local options = self:GetModuleOptions("SpellBook", false)
    local size = options and tonumber(options.textSize)
    if not size then return nil end
    return math.max(8, math.min(32, math.floor(size + 0.5)))
end

function NSkin:GetSpellBookTextSize()
    return self:GetSpellBookTextSizeOverride()
        or State.original.spellTextSize or 16
end

function NSkin:SetSpellBookTextSize(size)
    size = tonumber(size)
    if not size then return false end

    size = math.max(8, math.min(32, math.floor(size + 0.5)))
    self:GetModuleOptions("SpellBook", true).textSize = size

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

function NSkin:GetSpellBookIconsPerRowOverride()
    local options = self:GetModuleOptions("SpellBook", false)
    local value = options and tonumber(options.iconsPerRow)
    if not value then return nil end
    value = math.floor(value + 0.5)
    return (value == 2 or value == 3 or value == 4) and value or nil
end

function NSkin:GetSpellBookIconsPerRow()
    return self:GetSpellBookIconsPerRowOverride()
        or State.original.iconsPerRow or 0
end

function NSkin:SetSpellBookIconsPerRow(value)
    value = math.floor((tonumber(value) or 0) + 0.5)
    if value == 0 then return self:ResetSpellBookIconsPerRow() end
    if value ~= 2 and value ~= 3 and value ~= 4 then return false end
    self:GetModuleOptions("SpellBook", true).iconsPerRow = value
    if SpellBookSkin.ApplyIconDisposition then
        SpellBookSkin:ApplyIconDisposition()
    end
    return true
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


function NSkin:ResetSpellBookIconsPerRow()
    self:RemoveModuleOption("SpellBook", "iconsPerRow")
    if SpellBookSkin.ApplyIconDisposition then SpellBookSkin:ApplyIconDisposition() end
    return true
end


function NSkin:ResetSpellBookTextSize()
    self:RemoveModuleOption("SpellBook", "textSize")
    if SpellBookSkin.RefreshTextSize then SpellBookSkin:RefreshTextSize() end
    return true
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

local function SetFontSize(fontString, size)
    if not fontString or not size then return end

    local font, _, flags = fontString:GetFont()
    if font then fontString:SetFont(font, size, flags) end
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

    if not State.assistedCombatDivider then
        State.assistedCombatDivider = frame:CreateTexture(nil, "ARTWORK", nil, 1)
        State.assistedCombatDivider:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -2)
        State.assistedCombatDivider:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 2)
        State.assistedCombatDivider:SetWidth(1)
    end
    State.assistedCombatDivider:SetColorTexture(unpack(NSkin:GetStyle("window").header.divider))
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
        State.assistedCombatDivider:Hide()
        if frame.Button then frame.Button:Hide() end
        frame:EnableMouse(false)
        frame:SetAlpha(0)
        frame:Hide()
        data.assistantHiddenByNSkin = true
    elseif data.assistantHiddenByNSkin then
        if frame.Label then frame.Label:Show() end
        if assistantIcon then assistantIcon:Show() end
        if assistantBorder then NSkin:SetPixelBorderShown(assistantBorder, true) end
        State.assistedCombatDivider:Show()
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
    local style = NSkin:GetAppearanceStyle("window", IDs.AppearanceWindow, IDs.Window)
    NSkin:SkinWindow(playerSpells, nil, style,
        NSkin:GetAppearanceBorderColor(
            "window", style, IDs.AppearanceWindow, IDs.Window))
    if playerSpells.TitleContainer and playerSpells.TitleContainer.TitleText then
        local title = playerSpells.TitleContainer.TitleText
        title:SetTextColor(unpack(
            NSkin:GetResolvedAppearanceColor(style.header, "text")))
        NSkin:ApplyResolvedTypography(title, style.header)
    end

    NSkin:SkinWindowHeader(playerSpells, style.header)
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
    if State.paginationController then State.paginationController:Refresh() end

    RemoveSpellBookPortraitAndHelp(playerSpells, spellBook)
    SkinTitleBar(playerSpells, spellBook)
    SkinSpellBookTabs()
    local searchStyle = NSkin:GetAppearanceStyle(
        "searchBox", IDs.AppearanceWindow, IDs.Search.Group)
    NSkin:SkinSearchBox(spellBook.SearchBox, searchStyle,
        NSkin:GetAppearanceBorderColor(
            "searchBox", searchStyle, IDs.AppearanceWindow, IDs.Search.Group))
    NSkin:SkinPagingControls(pagedSpells and pagedSpells.PagingControls)
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

    local iconCrop = NSkin:GetStyle("icon").crop
    icon:SetTexCoord(iconCrop, 1 - iconCrop, iconCrop, 1 - iconCrop)
    if button.Cooldown then
        button.Cooldown:ClearAllPoints()
        button.Cooldown:SetAllPoints(icon)
    end

    local spellInfo = item.spellBookItemInfo
    local isPassive = spellInfo and spellInfo.isPassive

    -- Keep functional overlays while removing Blizzard's ornamental artwork.
    if item.Backplate then item.Backplate:SetAlpha(0) end
    local textColor = NSkin:GetStyle("button").text
    if item.Name then
        local textData = NSkin:GetSkinData(item.Name, SPELL_BOOK_STATE)
        if not textData.originalFont then
            textData.originalFont = { item.Name:GetFont() }
            State.original.spellTextSize = State.original.spellTextSize
                or textData.originalFont[2]
        end
        item.Name:SetTextColor(unpack(textColor))
        local sizeOverride = NSkin:GetSpellBookTextSizeOverride()
        if sizeOverride then
            SetFontSize(item.Name, sizeOverride)
        elseif textData.originalFont[1] then
            item.Name:SetFont(unpack(textData.originalFont))
        end
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
    local style = NSkin:GetAppearanceStyle(
        "sectionHeader", IDs.AppearanceWindow, IDs.Headers)
    local offset = NSkin:GetSpellBookHeaderOffset()
    if header.Text then
        local textData = NSkin:GetSkinData(header.Text, SPELL_BOOK_STATE)
        if not textData.originalPoints then
            textData.originalPoints = {}
            for i = 1, header.Text:GetNumPoints() do
                textData.originalPoints[i] = { header.Text:GetPoint(i) }
            end
        end
        header.Text:ClearAllPoints()
        for i = 1, #textData.originalPoints do
            local point = textData.originalPoints[i]
            header.Text:SetPoint(point[1], point[2], point[3],
                (point[4] or 0) + offset.offsetX,
                (point[5] or 0) + offset.offsetY)
        end
        header.Text:SetTextColor(unpack(
            NSkin:GetResolvedAppearanceColor(style, "text")))
        NSkin:ApplyResolvedTypography(header.Text, style)
    end
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
    data.headerLine:ClearAllPoints()
    data.headerLine:SetPoint("BOTTOMLEFT", header, "BOTTOMLEFT",
        -8 + offset.offsetX, 12 + offset.offsetY)
    data.headerLine:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT",
        -60 + offset.offsetX, 12 + offset.offsetY)
    data.headerLine:SetHeight(style.underlineSize)
    data.headerLine:SetColorTexture(unpack(
        NSkin:GetResolvedAppearanceColor(style, "underline")))
    data.headerLine:SetShown(style.underlineVisible == true)
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

    local size = NSkin:GetSpellBookTextSizeOverride()
    for _, frame in pagedSpells:EnumerateFrames() do
        if frame.HasValidData and frame:HasValidData() and frame.Name then
            local data = NSkin:GetSkinData(frame.Name, SPELL_BOOK_STATE)
            if size then
                SetFontSize(frame.Name, size)
            elseif data.originalFont and data.originalFont[1] then
                frame.Name:SetFont(unpack(data.originalFont))
            end
        end
    end
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

function SpellBookSkin:RefreshAssistant()
    if not NSkin:IsModuleEnabled("SpellBook") then return end
    local playerSpells = _G.PlayerSpellsFrame
    local spellBook = playerSpells and playerSpells.SpellBookFrame
    local frame = spellBook and spellBook.AssistedCombatRotationSpellFrame
    if frame then SkinAssistedCombat(frame) end
end

function SpellBookSkin:ApplyIconDisposition()
    if not NSkin:IsModuleEnabled("SpellBook") then return false end
    local playerSpells = _G.PlayerSpellsFrame
    local spellBook = playerSpells and playerSpells.SpellBookFrame
    local pagedSpells = spellBook and spellBook.PagedSpellsFrame
    if not pagedSpells then return false end
    State.original.iconsPerRow = State.original.iconsPerRow
        or pagedSpells.columnsPerRow
    local columns = NSkin:GetSpellBookIconsPerRowOverride()
        or State.original.iconsPerRow
    if pagedSpells.columnsPerRow == columns then return true end
    pagedSpells.columnsPerRow = columns
    if type(spellBook.UpdateDisplayedSpells) == "function" then
        spellBook:UpdateDisplayedSpells(true, false)
    end
    return true
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
        highlightRegions = function()
            local regions = {}
            if pagedSpells and pagedSpells.EnumerateFrames then
                for _, frame in pagedSpells:EnumerateFrames() do
                    if not (frame.HasValidData and frame:HasValidData()) and frame.Text then
                        regions[#regions + 1] = frame.Text
                        local data = NSkin:GetSkinData(frame, SPELL_BOOK_STATE, false)
                        if data and data.headerLine then regions[#regions + 1] = data.headerLine end
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
