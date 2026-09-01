local _, NSkin = ...

local EncounterJournalSkin = NSkin:NewModule("EncounterJournal")
local ENCOUNTER_JOURNAL_STATE = "encounterJournal"
local IDs = {
    AppearanceWindow = "EncounterJournal",
    Window = "EncounterJournal.Window",
    NavigationBar = "EncounterJournal.NavigationBar",
    MainTabs = "EncounterJournal.MainTabs",
    Journeys = {
        Scope = "EncounterJournal.Journeys",
        SeasonDropdown = "EncounterJournal.Journeys.SeasonDropdown",
        ScrollBar = "EncounterJournal.Journeys.ScrollBar",
    },
    TravelersLog = {
        Scope = "EncounterJournal.TravelersLog",
        ScrollBar = "EncounterJournal.TravelersLog.ScrollBar",
        FilterScrollBar = "EncounterJournal.TravelersLog.FilterScrollBar",
    },
    Suggested = {
        Scope = "EncounterJournal.SuggestedContent",
        Text = "EncounterJournal.SuggestedContent.Text",
        Buttons = {
            "EncounterJournal.SuggestedContent.AcceptQuest1",
            "EncounterJournal.SuggestedContent.AcceptQuest2",
            "EncounterJournal.SuggestedContent.AcceptQuest3",
        },
    },
    Tutorials = {
        Scope = "EncounterJournal.Tutorials",
        Text = "EncounterJournal.Tutorials.Text",
        StartButton = "EncounterJournal.Tutorials.StartButton",
    },
    Instances = {
        Scope = "EncounterJournal.Instances",
        Search = "EncounterJournal.Instances.SearchBox",
        ScrollBar = "EncounterJournal.Instances.ScrollBar",
    },
}

NSkin:RegisterAppearanceScope(IDs.AppearanceWindow, {
    label = "Adventure Guide",
})
NSkin:RegisterAppearanceScope(IDs.Journeys.Scope, {
    label = "Journeys", parent = IDs.AppearanceWindow,
})
NSkin:RegisterAppearanceScope(IDs.TravelersLog.Scope, {
    label = "Traveler's Log", parent = IDs.AppearanceWindow,
})
NSkin:RegisterAppearanceScope(IDs.Suggested.Scope, {
    label = "Suggested Content", parent = IDs.AppearanceWindow,
})
NSkin:RegisterAppearanceScope(IDs.Tutorials.Scope, {
    label = "Tutorials", parent = IDs.AppearanceWindow,
})
NSkin:RegisterAppearanceScope(IDs.Instances.Scope, {
    label = "Dungeons and Raids", parent = IDs.AppearanceWindow,
})

local BORDER_SIZE = 1
local CLEAR_TEXTURE = 0

-- EncounterInstanceButtonTemplate uses only this subregion of its source
-- texture. These values add a small zoom while remaining inside that region.
local CROP_LEFT = 0.035
local CROP_RIGHT = 0.648
local CROP_TOP = 0.045
local CROP_BOTTOM = 0.697
local JOURNEY_CARD_CROP_X = 0.05
local JOURNEY_CARD_CROP_Y = 0.12
local JOURNEY_CARD_INSET = 6

local initialized = false
local hookedScrollBox
local refreshPending = false
local refreshPasses = 0
local lastTabID
local bossScrollBox
local concealedScrollBox
local concealedOriginalAlpha
local journeysRegistered = false
local windowRegistered = false
local tabsRegistered = false
local suggestedButtonsRegistered = {}
local suggestedTextRegistered = false
local tutorialsButtonRegistered = false
local tutorialsTextRegistered = false
local instanceControlsRegistered = false
local journeysScrollBarRegistered = false
local travelersScrollBarRegistered = false
local travelersFilterScrollBarRegistered = false
local journeysListHooked = false

local function GetAdventureGuideTabs(journal)
    local tabs = {}
    for _, key in ipairs({ "JourneysTab", "MonthlyActivitiesTab",
        "suggestTab", "dungeonsTab", "raidsTab", "LootJournalTab",
        "TutorialsTab" }) do
        local tab = journal and journal[key]
        if tab then tabs[#tabs + 1] = tab end
    end
    return tabs
end

local function AddTextRegion(regions, fontString)
    if fontString and fontString.GetFont then regions[#regions + 1] = fontString end
end

local function GetSuggestionTextRegions(suggestion)
    local regions = {}
    local display = suggestion and suggestion.centerDisplay
    AddTextRegion(regions, display and display.title and display.title.text)
    AddTextRegion(regions, display and display.description and display.description.text)
    AddTextRegion(regions, suggestion and suggestion.reward and suggestion.reward.text)
    return regions
end

local GetOrCreateHover

local function StyleJourneyCard(button)
    if not button or not (button.RenownCardFactionName or button.JourneyCardName) then
        return
    end

    local data = NSkin:GetSkinData(button, ENCOUNTER_JOURNAL_STATE)
    local surface = data.journeyCardSurface
    if not surface then
        surface = CreateFrame("Frame", nil, button)
        surface:SetFrameLevel(button:GetFrameLevel())
        data.journeyCardSurface = surface
    end
    if not data.journeyCardHighlightSuppressed then
        button.UpdateHighlightForState = function(card)
            card:SetHighlightTexture(CLEAR_TEXTURE)
            local highlight = card.GetHighlightTexture and card:GetHighlightTexture()
            if highlight then highlight:SetAlpha(0) end
        end
        data.journeyCardHighlightSuppressed = true
    end

    -- AlphaHighlightButtonMixin uses the normal atlas on hover and the pushed
    -- atlas while clicked. Disable that overlay, and make the pushed texture
    -- reuse the normal artwork so clicking never makes the card disappear.
    button:UpdateHighlightForState()
    if button.NormalTexture and button.PushedTexture then
        local normalAtlas = button.NormalTexture:GetAtlas()
        if normalAtlas then button.PushedTexture:SetAtlas(normalAtlas, false) end
        button.PushedTexture:SetAlpha(1)
    end

    local pixel = NSkin:GetPhysicalPixelSize(button)
    local inset = JOURNEY_CARD_INSET * pixel
    surface:ClearAllPoints()
    surface:SetPoint("TOPLEFT", button, "TOPLEFT", inset, -inset)
    surface:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -inset, inset)
    for _, texture in ipairs({ button.NormalTexture, button.PushedTexture }) do
        if texture then
            texture:ClearAllPoints()
            texture:SetPoint("TOPLEFT", surface, "TOPLEFT", pixel, -pixel)
            texture:SetPoint("BOTTOMRIGHT", surface, "BOTTOMRIGHT", -pixel, pixel)
            -- The bevel is baked into the atlas. Crop it away while retaining
            -- the card artwork that lies inside it.
            texture:SetTexCoord(
                JOURNEY_CARD_CROP_X, 1 - JOURNEY_CARD_CROP_X,
                JOURNEY_CARD_CROP_Y, 1 - JOURNEY_CARD_CROP_Y)
        end
    end

    local color = NSkin:GetSharedBorderColor()
    local border = NSkin:CreatePixelBorder(button,
        "__NSkinJourneyCardBorder", 1, color, false, surface)
    NSkin:SetPixelBorderSize(border, 1)
    NSkin:SetPixelBorderColor(border, unpack(color))

    local hover = GetOrCreateHover(button)
    hover:ClearAllPoints()
    hover:SetPoint("TOPLEFT", surface, "TOPLEFT", pixel, -pixel)
    hover:SetPoint("BOTTOMRIGHT", surface, "BOTTOMRIGHT", -pixel, pixel)
    if button.IsMouseOver then hover:SetShown(button:IsMouseOver()) end
end

local function StyleJourneyListFrame(frame)
    if frame and frame.CategoryDivider then
        frame.CategoryDivider:SetAlpha(0)
        frame.CategoryDivider:Hide()
    end
    StyleJourneyCard(frame)
end

local function StyleVisibleJourneyCards(journeysList)
    if not journeysList or not journeysList.ForEachFrame then return end
    journeysList:ForEachFrame(StyleJourneyListFrame)
end

local cardFrameAtlases = {
    ["shop-card-wide-frame-default"] = true,
    ["shop-card-wide-frame-hover"] = true,
}

local function ClearButtonTextures(button)
    if not button then return end
    button:SetNormalTexture(CLEAR_TEXTURE)
    button:SetPushedTexture(CLEAR_TEXTURE)
    button:SetHighlightTexture(CLEAR_TEXTURE)
    if button.SetDisabledTexture then button:SetDisabledTexture(CLEAR_TEXTURE) end
end

local function IsTexture(region)
    return region and region.IsObjectType and region:IsObjectType("Texture")
end

local function IsFontString(region)
    return region and region.IsObjectType and region:IsObjectType("FontString")
end

local function RemoveMasks(texture)
    if not texture.GetNumMaskTextures
        or not texture.GetMaskTexture
        or not texture.RemoveMaskTexture
    then
        return
    end

    local masks = {}
    for i = 1, texture:GetNumMaskTextures() do
        masks[#masks + 1] = texture:GetMaskTexture(i)
    end
    for i = 1, #masks do
        if masks[i] then texture:RemoveMaskTexture(masks[i]) end
    end
end

function EncounterJournalSkin:StyleBossButton(button)
    if not button or not button.creature or not button.text then return end

    ClearButtonTextures(button)

    local data = NSkin:GetSkinData(button, ENCOUNTER_JOURNAL_STATE)
    local background = data.bossBackground
    if not background then
        background = button:CreateTexture(nil, "BACKGROUND", nil, -7)
        background:SetAllPoints(button)
        data.bossBackground = background
    end
    background:SetColorTexture(unpack(NSkin:GetStyle("encounterCard").background))
    background:Show()
end

function EncounterJournalSkin:StyleBossFrames(scrollBox)
    if not scrollBox or not scrollBox.ForEachFrame then return end
    scrollBox:ForEachFrame(function(button)
        EncounterJournalSkin:StyleBossButton(button)
    end)
end

function EncounterJournalSkin:StyleInstancePage()
    local journal = _G.EncounterJournal
    local encounter = journal and journal.encounter
    local instance = encounter and encounter.instance
    local info = encounter and encounter.info
    if not instance or not info then return end

    -- The lore image contains its ornamental frame in the source texture.
    -- Use the image-only portion and rotate it back into its original
    -- orientation, producing a clean rectangular dungeon image.
    local loreImage = instance.loreBG
    if IsTexture(loreImage) then
        loreImage:SetTexCoord(0.71, 0.06, 0.582, 0.08)
        if loreImage.SetRotation then loreImage:SetRotation(math.rad(180)) end

        local data = NSkin:GetSkinData(instance, ENCOUNTER_JOURNAL_STATE)
        local imageBorder = data.loreImageBorder
        if not imageBorder then
            imageBorder = CreateFrame("Frame", nil, instance)
            imageBorder:SetPoint("TOPLEFT", loreImage, "TOPLEFT", -1, 1)
            imageBorder:SetPoint("BOTTOMRIGHT", loreImage, "BOTTOMRIGHT", 1, -1)
            imageBorder:SetFrameLevel(instance:GetFrameLevel() + 1)
            data.loreImageBorder = imageBorder
        end
        local border = NSkin:CreatePixelBorder(
            imageBorder,
            "__NSkinBorder",
            BORDER_SIZE,
            NSkin:GetBorderAccentColor(),
            false
        )
        NSkin:SetPixelBorderColor(border, unpack(NSkin:GetBorderAccentColor()))
    end

    if instance.titleBG then
        instance.titleBG:SetAlpha(0)
        instance.titleBG:Hide()
    end

    local instanceButton = info.instanceButton
    if instanceButton and IsTexture(instanceButton.icon) then
        ClearButtonTextures(instanceButton)
        -- This inherited icon keeps a Blizzard-owned mask that cannot be
        -- reliably detached. SetTexCoord is illegal while that mask exists,
        -- so preserve its native coordinates instead of generating errors.
    end

    self:StyleBossFrames(info.BossesScrollBox)
end

local function StripCardFrameAtlases(button)
    if not button.GetRegions then return end

    local regions = { button:GetRegions() }
    for i = 1, #regions do
        local region = regions[i]
        if IsTexture(region) then
            local atlas = region.GetAtlas and region:GetAtlas() or nil
            local data = NSkin:GetSkinData(region, ENCOUNTER_JOURNAL_STATE, false)
            if (data and data.encounterCardFrame) or cardFrameAtlases[atlas] then
                data = data or NSkin:GetSkinData(region, ENCOUNTER_JOURNAL_STATE)
                data.encounterCardFrame = true
                if region.SetAtlas then region:SetAtlas(nil) end
                region:SetTexture(nil)
                region:SetAlpha(0)
                region:Hide()
            end
        end
    end
end

GetOrCreateHover = function(button)
    local data = NSkin:GetSkinData(button, ENCOUNTER_JOURNAL_STATE)
    local hover = data.encounterHover
    if hover then
        hover:SetColorTexture(unpack(NSkin:GetStyle("encounterCard").hover))
        return hover
    end

    hover = button:CreateTexture(nil, "ARTWORK", nil, 7)
    hover:SetPoint("TOPLEFT", button, "TOPLEFT", BORDER_SIZE, -BORDER_SIZE)
    hover:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -BORDER_SIZE, BORDER_SIZE)
    hover:SetColorTexture(unpack(NSkin:GetStyle("encounterCard").hover))
    hover:SetBlendMode("ADD")
    hover:Hide()
    data.encounterHover = hover

    button:HookScript("OnEnter", function(self)
        local buttonData = NSkin:GetSkinData(self, ENCOUNTER_JOURNAL_STATE, false)
        local overlay = buttonData and buttonData.encounterHover
        if overlay then overlay:Show() end
    end)
    button:HookScript("OnLeave", function(self)
        local buttonData = NSkin:GetSkinData(self, ENCOUNTER_JOURNAL_STATE, false)
        local overlay = buttonData and buttonData.encounterHover
        if overlay then overlay:Hide() end
    end)

    return hover
end

function EncounterJournalSkin:StyleButton(button)
    local background = button and button.bgImage
    if not button
        or not IsTexture(background)
        or not IsFontString(button.name)
    then
        return
    end

    RemoveMasks(background)

    background:ClearAllPoints()
    background:SetPoint("TOPLEFT", button, "TOPLEFT", BORDER_SIZE, -BORDER_SIZE)
    background:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -BORDER_SIZE, BORDER_SIZE)
    background:SetTexCoord(CROP_LEFT, CROP_RIGHT, CROP_TOP, CROP_BOTTOM)
    background:SetAlpha(1)
    background:Show()

    local border = NSkin:CreatePixelBorder(
        button,
        "__NSkinEncounterBorder",
        BORDER_SIZE,
        NSkin:GetBorderAccentColor(),
        false
    )
    NSkin:SetPixelBorderColor(border, unpack(NSkin:GetBorderAccentColor()))

    ClearButtonTextures(button)
    StripCardFrameAtlases(button)
    local hover = GetOrCreateHover(button)
    if button.IsMouseOver then hover:SetShown(button:IsMouseOver()) end
    button.name:SetDrawLayer("OVERLAY", 6)
end

function EncounterJournalSkin:OnInitializedFrame(button)
    self:StyleButton(button)
    self:QueueRefresh()
end

function EncounterJournalSkin:StyleVisibleFrames(scrollBox)
    if not scrollBox or not scrollBox.ForEachFrame then return end
    scrollBox:ForEachFrame(function(button)
        EncounterJournalSkin:StyleButton(button)
    end)
end

function EncounterJournalSkin:RefreshAppearance()
    if not initialized then return end
    self:RegisterSharedNavigationBar()
    self:StyleSharedWindow()
    self:StyleJourneys()
    self:StyleTravelersLog()
    self:StyleSuggestedContent()
    self:StyleTutorials()
    self:StyleContentBackground()
    self:StyleInstanceControls()
    self:StyleJournalScrollBars()
    self:StyleAdventureGuideTabs()
    self:StyleVisibleFrames(hookedScrollBox)
    self:StyleBossFrames(bossScrollBox)
    self:StyleInstancePage()
end

function EncounterJournalSkin:RegisterSharedNavigationBar()
    local journal = _G.EncounterJournal
    local navigationBar = journal and journal.navBar
    if not journal or not navigationBar then return end
    NSkin:RegisterNavigationBar(IDs.NavigationBar, {
        module = "EncounterJournal",
        appearanceWindowID = IDs.AppearanceWindow,
        label = "Adventure Guide navigation bar",
        window = journal,
        target = navigationBar,
        priority = 40,
        highlightRegions = { navigationBar },
        isEditable = function()
            return journal:IsVisible() and navigationBar:IsVisible()
        end,
    })
end

function EncounterJournalSkin:StyleContentBackground(selectedTab)
    local journal = _G.EncounterJournal
    local instanceSelect = journal and journal.instanceSelect
    if not journal or not instanceSelect then return end
    selectedTab = selectedTab or journal.selectedTab
    local journeysTabID = journal.JourneysTab and journal.JourneysTab:GetID()
    local travelersTabID = journal.MonthlyActivitiesTab
        and journal.MonthlyActivitiesTab:GetID()
    local suggestedTabID = journal.suggestTab and journal.suggestTab:GetID()
    local dungeonTabID = journal.dungeonsTab and journal.dungeonsTab:GetID()
    local raidTabID = journal.raidsTab and journal.raidsTab:GetID()
    local tutorialsTabID = journal.TutorialsTab and journal.TutorialsTab:GetID()
    local hideBackground = selectedTab == journeysTabID
        or selectedTab == travelersTabID
        or selectedTab == suggestedTabID or selectedTab == dungeonTabID
        or selectedTab == raidTabID or selectedTab == tutorialsTabID
    if instanceSelect.bg then
        instanceSelect.bg:SetAlpha(hideBackground and 0 or 1)
    end
    if instanceSelect.evergreenBg then
        instanceSelect.evergreenBg:SetAlpha(hideBackground and 0 or 1)
    end
end

function EncounterJournalSkin:StyleTravelersLog(forceShown)
    local journal = _G.EncounterJournal
    local travelersLog = journal and journal.MonthlyActivitiesFrame
    if not travelersLog then return end

    local travelersTabID = journal.MonthlyActivitiesTab
        and journal.MonthlyActivitiesTab:GetID()
    local shown = forceShown
    if shown == nil then shown = journal.selectedTab == travelersTabID end
    if not shown then return end

    -- Remove only the full-page artwork. Filter, reward-track and activity-card
    -- textures are children of their own containers and remain intact.
    for _, texture in ipairs({
        travelersLog.Bg,
        travelersLog.DividerVertical,
        travelersLog.ShadowLeft,
        travelersLog.ShadowRight,
        travelersLog.Divider,
    }) do
        if texture then texture:SetAlpha(0) end
    end

    local theme = travelersLog.ThemeContainer
    if theme then
        for _, texture in ipairs({
            theme.Top, theme.Bottom, theme.Left, theme.Right, theme.FilterList,
        }) do
            if texture then texture:SetAlpha(0) end
        end
    end
end

function EncounterJournalSkin:StyleInstanceControls(forceShown)
    local journal = _G.EncounterJournal
    local instanceSelect = journal and journal.instanceSelect
    if not journal or not instanceSelect then return end
    local dungeonTabID = journal.dungeonsTab and journal.dungeonsTab:GetID()
    local raidTabID = journal.raidsTab and journal.raidsTab:GetID()
    local shown = forceShown
    if shown == nil then
        shown = journal.selectedTab == dungeonTabID
            or journal.selectedTab == raidTabID
    end
    if not shown then
        if instanceControlsRegistered then
            NSkin:NotifySkinningElementBoundsChanged(IDs.Instances.Search)
            NSkin:NotifySkinningElementBoundsChanged(IDs.Instances.ScrollBar)
        end
        return
    end

    local searchBox = journal.searchBox
    local scrollBar = instanceSelect.ScrollBar
    local searchStyle = NSkin:GetAppearanceStyle(
        "searchBox", IDs.Instances.Scope, IDs.Instances.Search)
    NSkin:SkinSearchBox(searchBox, searchStyle,
        NSkin:GetAppearanceBorderColor("searchBox", searchStyle,
            IDs.Instances.Scope, IDs.Instances.Search))
    NSkin:SkinScrollBar(scrollBar, NSkin:GetAppearanceStyle(
        "scrollBar", IDs.Instances.Scope, IDs.Instances.ScrollBar))
    if not instanceControlsRegistered and searchBox and scrollBar then
        local function IsInstanceTabVisible(target)
            local selected = journal.selectedTab
            return (selected == dungeonTabID or selected == raidTabID)
                and target:IsVisible()
        end
        NSkin:RegisterSimpleMovableElement({
            id = IDs.Instances.Search,
            module = "EncounterJournal",
            appearanceWindowID = IDs.Instances.Scope,
            label = "Dungeons and raids search bar",
            kind = "SEARCH_GROUP",
            window = journal,
            target = searchBox,
            priority = 80,
            highlightRegions = { searchBox },
            isEditable = function()
                return IsInstanceTabVisible(searchBox)
            end,
        })
        NSkin:RegisterSimpleMovableElement({
            id = IDs.Instances.ScrollBar,
            module = "EncounterJournal",
            appearanceWindowID = IDs.Instances.Scope,
            label = "Dungeons and raids scroll bar",
            kind = "SCROLLBAR",
            window = journal,
            target = scrollBar,
            priority = 81,
            highlightRegions = { scrollBar },
            isEditable = function()
                return IsInstanceTabVisible(scrollBar)
            end,
        })
        instanceControlsRegistered = true
    elseif instanceControlsRegistered then
        NSkin:NotifySkinningElementBoundsChanged(IDs.Instances.Search)
        NSkin:NotifySkinningElementBoundsChanged(IDs.Instances.ScrollBar)
    end
end

function EncounterJournalSkin:StyleJournalScrollBars()
    local journal = _G.EncounterJournal
    local journeys = journal and journal.JourneysFrame
    local travelersLog = journal and journal.MonthlyActivitiesFrame
    if not journal then return end
    local journeysScrollBar = journeys and journeys.ScrollBar
    local travelersScrollBar = travelersLog and travelersLog.ScrollBar
    local travelersFilterScrollBar = travelersLog and travelersLog.FilterList
        and travelersLog.FilterList.ScrollBar
    NSkin:SkinScrollBar(journeysScrollBar, NSkin:GetAppearanceStyle(
        "scrollBar", IDs.Journeys.Scope, IDs.Journeys.ScrollBar))
    NSkin:SkinScrollBar(travelersScrollBar, NSkin:GetAppearanceStyle(
        "scrollBar", IDs.TravelersLog.Scope, IDs.TravelersLog.ScrollBar))
    NSkin:SkinScrollBar(travelersFilterScrollBar, NSkin:GetAppearanceStyle(
        "scrollBar", IDs.TravelersLog.Scope, IDs.TravelersLog.FilterScrollBar))
    if journeysScrollBar and not journeysScrollBarRegistered then
        NSkin:RegisterSimpleMovableElement({
            id = IDs.Journeys.ScrollBar,
            module = "EncounterJournal",
            appearanceWindowID = IDs.Journeys.Scope,
            label = "Journeys scroll bar",
            kind = "SCROLLBAR",
            window = journal,
            target = journeysScrollBar,
            priority = 81,
            highlightRegions = { journeysScrollBar },
            isEditable = function()
                return journeys:IsVisible() and journeysScrollBar:IsVisible()
            end,
        })
        journeysScrollBarRegistered = true
    elseif journeysScrollBarRegistered then
        NSkin:NotifySkinningElementBoundsChanged(IDs.Journeys.ScrollBar)
    end
    if travelersScrollBar and not travelersScrollBarRegistered then
        NSkin:RegisterSimpleMovableElement({
            id = IDs.TravelersLog.ScrollBar,
            module = "EncounterJournal",
            appearanceWindowID = IDs.TravelersLog.Scope,
            label = "Traveler's Log scroll bar",
            kind = "SCROLLBAR",
            window = journal,
            target = travelersScrollBar,
            priority = 81,
            highlightRegions = { travelersScrollBar },
            isEditable = function()
                return travelersLog:IsVisible()
                    and travelersScrollBar:IsVisible()
            end,
        })
        travelersScrollBarRegistered = true
    elseif travelersScrollBarRegistered then
        NSkin:NotifySkinningElementBoundsChanged(
            IDs.TravelersLog.ScrollBar)
    end
    if travelersFilterScrollBar and not travelersFilterScrollBarRegistered then
        NSkin:RegisterSimpleMovableElement({
            id = IDs.TravelersLog.FilterScrollBar,
            module = "EncounterJournal",
            appearanceWindowID = IDs.TravelersLog.Scope,
            label = "Traveler's Log filter scroll bar",
            kind = "SCROLLBAR",
            window = journal,
            target = travelersFilterScrollBar,
            priority = 82,
            highlightRegions = { travelersFilterScrollBar },
            isEditable = function()
                return travelersLog:IsVisible()
                    and travelersFilterScrollBar:IsVisible()
            end,
        })
        travelersFilterScrollBarRegistered = true
    elseif travelersFilterScrollBarRegistered then
        NSkin:NotifySkinningElementBoundsChanged(
            IDs.TravelersLog.FilterScrollBar)
    end
end

function EncounterJournalSkin:StyleAdventureGuideTabs(selectedTab)
    local journal = _G.EncounterJournal
    if not journal then return end
    selectedTab = selectedTab or journal.selectedTab
    local tabs = GetAdventureGuideTabs(journal)
    local style = NSkin:GetAppearanceStyle(
        "tab", IDs.AppearanceWindow, IDs.MainTabs)
    local borderColor = NSkin:GetAppearanceBorderColor(
        "tab", style, IDs.AppearanceWindow, IDs.MainTabs)
    for i = 1, #tabs do
        NSkin:SkinTab(tabs[i], tabs[i]:GetID() == selectedTab,
            style, borderColor)
    end
    if NSkin:GetTabGroup(IDs.MainTabs) then
        NSkin:ApplyTabGroupLayout(IDs.MainTabs)
    end
end

function EncounterJournalSkin:StyleSuggestedContent(forceShown)
    local journal = _G.EncounterJournal
    local suggestFrame = journal and journal.suggestFrame
    if not suggestFrame then return end
    local suggestedTabID = journal.suggestTab and journal.suggestTab:GetID()
    local shown = forceShown
    if shown == nil then shown = journal.selectedTab == suggestedTabID end
    local inset = journal.Inset or _G.EncounterJournalInset
    if inset then
        if inset.NineSlice then inset.NineSlice:Hide() end
        if inset.Bg then inset.Bg:Hide() end
        if inset.Background then inset.Background:Hide() end
    end
    local title = journal.instanceSelect and journal.instanceSelect.Title
    if title then
        local data = NSkin:GetSkinData(title, ENCOUNTER_JOURNAL_STATE)
        if not data.suggestedOriginalColor then
            data.suggestedOriginalColor = { title:GetTextColor() }
        end
        if shown then
            NSkin:SkinText(title, NSkin:GetAppearanceStyle(
                "text", IDs.Suggested.Scope, IDs.Suggested.Text))
        else
            title:SetTextColor(unpack(data.suggestedOriginalColor))
        end
    end
    local textStyle = NSkin:GetAppearanceStyle(
        "text", IDs.Suggested.Scope, IDs.Suggested.Text)
    local suggestions = { suggestFrame.Suggestion1,
        suggestFrame.Suggestion2, suggestFrame.Suggestion3 }
    local textRegions = {}
    for _, suggestion in ipairs(suggestions) do
        if suggestion then
            if suggestion.bg then
                suggestion.bg:SetAlpha(1)
                suggestion.bg:Show()
            end
            for _, fontString in ipairs(GetSuggestionTextRegions(suggestion)) do
                textRegions[#textRegions + 1] = fontString
                if shown then NSkin:SkinText(fontString, textStyle) end
            end
        end
    end
    if shown and title and not suggestedTextRegistered then
        NSkin:RegisterSkinningElement(IDs.Suggested.Text, {
            module = "EncounterJournal",
            appearanceWindowID = IDs.Suggested.Scope,
            label = "Suggested Content text",
            kind = "TEXT",
            window = journal,
            target = title,
            draggable = false,
            priority = 70,
            highlightRegions = textRegions,
            isEditable = function()
                return suggestFrame:IsVisible() and title:IsVisible()
            end,
        })
        suggestedTextRegistered = true
    elseif suggestedTextRegistered then
        NSkin:NotifySkinningElementBoundsChanged(IDs.Suggested.Text)
    end
    if shown then
        for i = 1, #suggestions do
            local suggestion = suggestions[i]
            local button = suggestion and suggestion.button
            if button then
                NSkin:SkinActionButton(button, { style = NSkin:GetAppearanceStyle(
                    "button", IDs.Suggested.Scope, IDs.Suggested.Buttons[i]) })
            end
            if button and not suggestedButtonsRegistered[i] then
                NSkin:RegisterSimpleMovableElement({
                    id = IDs.Suggested.Buttons[i],
                    module = "EncounterJournal",
                    appearanceWindowID = IDs.Suggested.Scope,
                    label = "Suggested Content accept quest button " .. i,
                    kind = "ACTION_BUTTON",
                    window = journal,
                    target = button,
                    priority = 80 + i,
                    highlightRegions = { button },
                    isEditable = function()
                        return suggestFrame:IsVisible() and button:IsVisible()
                    end,
                })
                suggestedButtonsRegistered[i] = true
            elseif suggestedButtonsRegistered[i] then
                NSkin:NotifySkinningElementBoundsChanged(IDs.Suggested.Buttons[i])
            end
        end
    end
end

function EncounterJournalSkin:StyleTutorials(forceShown)
    local journal = _G.EncounterJournal
    local tutorialsFrame = journal and journal.TutorialsFrame
    local contents = tutorialsFrame and tutorialsFrame.Contents
    if not journal or not tutorialsFrame or not contents then return end

    local tutorialsTabID = journal.TutorialsTab and journal.TutorialsTab:GetID()
    local shown = forceShown
    if shown == nil then shown = journal.selectedTab == tutorialsTabID end

    -- StyleSuggestedContent restores Blizzard's original section-title color
    -- whenever its page is inactive. Tutorials then deliberately overrides it.
    local title = journal.instanceSelect and journal.instanceSelect.Title
    if shown and title then
        NSkin:SkinText(title, NSkin:GetAppearanceStyle(
            "text", IDs.Tutorials.Scope, IDs.Tutorials.Text))
        if not tutorialsTextRegistered then
            NSkin:RegisterSkinningElement(IDs.Tutorials.Text, {
                module = "EncounterJournal",
                appearanceWindowID = IDs.Tutorials.Scope,
                label = "Tutorials title",
                kind = "TEXT",
                window = journal,
                target = title,
                draggable = false,
                priority = 70,
                highlightRegions = { title },
                isEditable = function()
                    return tutorialsFrame:IsVisible() and title:IsVisible()
                end,
            })
            tutorialsTextRegistered = true
        else
            NSkin:NotifySkinningElementBoundsChanged(IDs.Tutorials.Text)
        end
    end

    local startButton = contents.StartButton
    if not startButton then return end
    NSkin:SkinActionButton(startButton, { style = NSkin:GetAppearanceStyle(
        "button", IDs.Tutorials.Scope, IDs.Tutorials.StartButton) })

    if shown and not tutorialsButtonRegistered then
        NSkin:RegisterSimpleMovableElement({
            id = IDs.Tutorials.StartButton,
            module = "EncounterJournal",
            appearanceWindowID = IDs.Tutorials.Scope,
            label = "Tutorials start button",
            kind = "ACTION_BUTTON",
            window = journal,
            target = startButton,
            priority = 80,
            highlightRegions = { startButton },
            isEditable = function()
                return tutorialsFrame:IsVisible() and startButton:IsVisible()
            end,
        })
        tutorialsButtonRegistered = true
    elseif tutorialsButtonRegistered then
        NSkin:NotifySkinningElementBoundsChanged(IDs.Tutorials.StartButton)
    end
end

function EncounterJournalSkin:StyleSharedWindow()
    local journal = _G.EncounterJournal
    if not journal then return end
    if journal.NineSlice then journal.NineSlice:Hide() end
    if journal.Bg then journal.Bg:Hide() end
    if journal.PortraitContainer then
        journal.PortraitContainer:SetAlpha(0)
        journal.PortraitContainer:Hide()
    elseif journal.portrait then
        journal.portrait:SetAlpha(0)
        journal.portrait:Hide()
    end

    local windowStyle = NSkin:GetAppearanceStyle(
        "window", IDs.AppearanceWindow, IDs.Window)
    NSkin:SkinWindow(journal, nil, windowStyle,
        NSkin:GetAppearanceBorderColor(
            "window", windowStyle, IDs.AppearanceWindow, IDs.Window))
    NSkin:SkinWindowHeader(journal, windowStyle.header)
    local title = journal.TitleContainer and journal.TitleContainer.TitleText
    if title then
        title:SetTextColor(unpack(
            NSkin:GetResolvedAppearanceColor(windowStyle.header, "text")))
        NSkin:ApplyResolvedTypography(title, windowStyle.header)
    end
    NSkin:SkinFlatButton(journal.CloseButton, "x", nil, nil, 20)
end

function EncounterJournalSkin:StyleJourneys(forceShown)
    local journal = _G.EncounterJournal
    local journeys = journal and journal.JourneysFrame
    local instanceSelect = journal and journal.instanceSelect
    local dropdown = instanceSelect and instanceSelect.ExpansionDropdown
    if not journal or not journeys then return end
    local journeysTabID = journal.JourneysTab and journal.JourneysTab:GetID()
    local selectedTab = journal.selectedTab
    local shown = forceShown
    if shown == nil then shown = selectedTab == journeysTabID end
    if not shown then return end

    -- QuestLogBorderFrameTemplate supplies the ornate outer frame and
    -- decorative flourishes behind the Journeys content.
    if journeys.BorderFrame then
        journeys.BorderFrame:SetAlpha(0)
        journeys.BorderFrame:Hide()
    end

    local journeysList = journeys.JourneysList
    StyleVisibleJourneyCards(journeysList)
    if journeysList and not journeysListHooked then
        if type(journeysList.Update) == "function" and hooksecurefunc then
            hooksecurefunc(journeysList, "Update", function(updatedList)
                StyleVisibleJourneyCards(updatedList)
            end)
        end
        local scrollEvents = _G.ScrollBoxListMixin and _G.ScrollBoxListMixin.Event
        if journeysList.RegisterCallback and scrollEvents
            and scrollEvents.OnInitializedFrame
        then
            journeysList:RegisterCallback(scrollEvents.OnInitializedFrame,
                function(_, frame) StyleJourneyListFrame(frame) end, self)
        end
        journeysListHooked = true
    end

    NSkin:SkinDropdown(dropdown, { style = NSkin:GetAppearanceStyle(
        "button", IDs.Journeys.Scope, IDs.Journeys.SeasonDropdown) })
    if not journeysRegistered and dropdown then
        NSkin:RegisterSimpleMovableElement({
            id = IDs.Journeys.SeasonDropdown,
            module = "EncounterJournal",
            appearanceWindowID = IDs.Journeys.Scope,
            label = "Journeys current season dropdown",
            kind = "DROPDOWN",
            window = journal,
            target = dropdown,
            priority = 80,
            highlightRegions = { dropdown },
            isEditable = function()
                return journeys:IsVisible() and dropdown:IsVisible()
            end,
        })
        journeysRegistered = true
    elseif journeysRegistered then
        NSkin:NotifySkinningElementBoundsChanged(
            IDs.Journeys.SeasonDropdown)
    end
end

local function FinishConcealment(scrollBox)
    if not concealedScrollBox or (scrollBox and scrollBox ~= concealedScrollBox) then
        return
    end

    concealedScrollBox:SetAlpha(concealedOriginalAlpha or 1)
    concealedScrollBox = nil
    concealedOriginalAlpha = nil
end

function EncounterJournalSkin:ConcealUntilStyled(scrollBox)
    if not scrollBox or not scrollBox.SetAlpha then return end

    if concealedScrollBox and concealedScrollBox ~= scrollBox then
        FinishConcealment()
    end

    if not concealedScrollBox then
        concealedScrollBox = scrollBox
        concealedOriginalAlpha = scrollBox:GetAlpha()
    end

    scrollBox:SetAlpha(0)
end

function EncounterJournalSkin:QueueRefresh()
    if refreshPending then return end
    refreshPending = true

    C_Timer.After(0, function()
        refreshPending = false
        if hookedScrollBox then
            refreshPasses = refreshPasses + 1
            EncounterJournalSkin:StyleVisibleFrames(hookedScrollBox)
            FinishConcealment(hookedScrollBox)
        end
    end)
end

function EncounterJournalSkin:OnTabSet(journal, tabID)
    lastTabID = tabID

    self:Initialize()
    self:StyleSharedWindow()
    self:StyleAdventureGuideTabs(tabID)
    self:StyleContentBackground(tabID)
    local suggestedTabID = journal and journal.suggestTab
        and journal.suggestTab:GetID()
    self:StyleSuggestedContent(tabID == suggestedTabID)
    local tutorialsTabID = journal and journal.TutorialsTab
        and journal.TutorialsTab:GetID()
    self:StyleTutorials(tabID == tutorialsTabID)
    local travelersTabID = journal and journal.MonthlyActivitiesTab
        and journal.MonthlyActivitiesTab:GetID()
    self:StyleTravelersLog(tabID == travelersTabID)
    local journeysTabID = journal and journal.JourneysTab
        and journal.JourneysTab:GetID()
    self:StyleJourneys(tabID == journeysTabID)
    self:StyleJournalScrollBars()

    local dungeonTabID = journal and journal.dungeonsTab and journal.dungeonsTab:GetID()
    local raidTabID = journal and journal.raidsTab and journal.raidsTab:GetID()
    self:StyleInstanceControls(
        tabID == dungeonTabID or tabID == raidTabID)
    if tabID ~= dungeonTabID and tabID ~= raidTabID then return end

    if hookedScrollBox then
        self:ConcealUntilStyled(hookedScrollBox)
        self:StyleVisibleFrames(hookedScrollBox)
    end
    self:QueueRefresh()
end

function EncounterJournalSkin:Initialize()
    if initialized then return true end
    if not NSkin:IsModuleEnabled("EncounterJournal") then return false end

    local journal = _G.EncounterJournal
    local instanceSelect = journal and journal.instanceSelect
    local scrollBox = instanceSelect and instanceSelect.ScrollBox
    local scrollEvents = _G.ScrollBoxListMixin and _G.ScrollBoxListMixin.Event

    if not scrollBox
        or not scrollBox.ForEachFrame
        or type(scrollBox.Update) ~= "function"
        or not hooksecurefunc
    then
        NSkin:Print("Encounter Journal skin could not attach to the Midnight ScrollBox update lifecycle.")
        return false
    end

    hookedScrollBox = scrollBox
    self:RegisterSharedNavigationBar()
    if not windowRegistered then
        NSkin:RegisterSkinningElement(IDs.Window, {
            module = "EncounterJournal",
            appearanceWindowID = IDs.AppearanceWindow,
            label = "Adventure Guide window",
            kind = "WINDOW",
            window = journal,
            target = journal,
            priority = 0,
            draggable = false,
        })
        windowRegistered = true
    end
    local info = journal.encounter and journal.encounter.info
    bossScrollBox = info and info.BossesScrollBox
    hooksecurefunc(scrollBox, "Update", function(updatedScrollBox)
        EncounterJournalSkin:StyleVisibleFrames(updatedScrollBox)
        FinishConcealment(updatedScrollBox)
        EncounterJournalSkin:QueueRefresh()
    end)

    if scrollBox.RegisterCallback
        and scrollEvents
        and scrollEvents.OnInitializedFrame
    then
        scrollBox:RegisterCallback(
            scrollEvents.OnInitializedFrame,
            self.OnInitializedFrame,
            self
        )
    end

    -- Style frames already present when the load-on-demand addon finishes.
    self:StyleVisibleFrames(scrollBox)
    self:QueueRefresh()

    if journal.HookScript then
        journal:HookScript("OnShow", function()
            NSkin:RefreshTabGroupBaseline(IDs.MainTabs, true)
            EncounterJournalSkin:StyleSharedWindow()
            EncounterJournalSkin:StyleJourneys()
            EncounterJournalSkin:StyleTravelersLog()
            EncounterJournalSkin:StyleSuggestedContent()
            EncounterJournalSkin:StyleTutorials()
            EncounterJournalSkin:StyleContentBackground()
            EncounterJournalSkin:StyleInstanceControls()
            EncounterJournalSkin:StyleJournalScrollBars()
            EncounterJournalSkin:StyleAdventureGuideTabs()
            EncounterJournalSkin:ConcealUntilStyled(scrollBox)
            EncounterJournalSkin:QueueRefresh()
        end)
        journal:HookScript("OnHide", function()
            FinishConcealment(scrollBox)
        end)
    end
    if instanceSelect.HookScript then
        instanceSelect:HookScript("OnShow", function()
            EncounterJournalSkin:ConcealUntilStyled(scrollBox)
            EncounterJournalSkin:QueueRefresh()
        end)
    end
    local suggestFrame = journal.suggestFrame
    if suggestFrame and suggestFrame.HookScript then
        suggestFrame:HookScript("OnShow", function()
            EncounterJournalSkin:StyleSuggestedContent(true)
            EncounterJournalSkin:StyleContentBackground(
                journal.suggestTab and journal.suggestTab:GetID())
        end)
    end
    local tutorialsFrame = journal.TutorialsFrame
    if tutorialsFrame and tutorialsFrame.HookScript then
        tutorialsFrame:HookScript("OnShow", function()
            EncounterJournalSkin:StyleSuggestedContent(false)
            EncounterJournalSkin:StyleTutorials(true)
            EncounterJournalSkin:StyleContentBackground(
                journal.TutorialsTab and journal.TutorialsTab:GetID())
        end)
    end
    local travelersLog = journal.MonthlyActivitiesFrame
    if travelersLog and travelersLog.HookScript then
        travelersLog:HookScript("OnShow", function()
            EncounterJournalSkin:StyleTravelersLog(true)
            EncounterJournalSkin:StyleContentBackground(
                journal.MonthlyActivitiesTab
                    and journal.MonthlyActivitiesTab:GetID())
        end)
        local theme = travelersLog.ThemeContainer
        if theme and theme.HookScript then
            theme:HookScript("OnShow", function()
                EncounterJournalSkin:StyleTravelersLog(true)
            end)
        end
    end
    if type(_G.EncounterJournal_ListInstances) == "function" then
        hooksecurefunc("EncounterJournal_ListInstances", function()
            EncounterJournalSkin:ConcealUntilStyled(scrollBox)
            EncounterJournalSkin:QueueRefresh()
        end)
    end


    if bossScrollBox and bossScrollBox.ForEachFrame and type(bossScrollBox.Update) == "function" then
        hooksecurefunc(bossScrollBox, "Update", function(updatedScrollBox)
            EncounterJournalSkin:StyleBossFrames(updatedScrollBox)
        end)

        if bossScrollBox.RegisterCallback
            and scrollEvents
            and scrollEvents.OnInitializedFrame
        then
            bossScrollBox:RegisterCallback(
                scrollEvents.OnInitializedFrame,
                self.StyleBossButton,
                self
            )
        end
    end

    if type(_G.EncounterJournal_DisplayInstance) == "function" then
        hooksecurefunc("EncounterJournal_DisplayInstance", function()
            EncounterJournalSkin:StyleInstancePage()
        end)
    end

    self:StyleInstancePage()
    self:StyleSharedWindow()
    self:StyleJourneys()
    self:StyleTravelersLog()
    self:StyleSuggestedContent()
    self:StyleTutorials()
    self:StyleContentBackground()
    self:StyleInstanceControls()
    self:StyleJournalScrollBars()
    if not tabsRegistered then
        NSkin:RegisterTabGroup(IDs.MainTabs, {
            module = "EncounterJournal",
            appearanceWindowID = IDs.AppearanceWindow,
            label = "Adventure Guide tabs",
            kind = "TAB_GROUP",
            window = journal,
            target = journal,
            tabs = GetAdventureGuideTabs(journal),
            priority = 50,
            orientation = "HORIZONTAL",
            edge = "BOTTOM",
            canCaptureBaseline = function()
                return journal:IsShown()
            end,
        })
        tabsRegistered = true
    end
    self:StyleAdventureGuideTabs()
    initialized = true
    return true
end

local function DescribeTexture(texture)
    if not texture then return "nil" end

    local name = texture.GetName and texture:GetName() or "<unnamed>"
    local shown = texture.IsShown and texture:IsShown() and "shown" or "hidden"
    local alpha = texture.GetAlpha and texture:GetAlpha() or "?"
    local path = texture.GetTexture and texture:GetTexture() or nil
    local atlas = texture.GetAtlas and texture:GetAtlas() or nil
    local layer, sublevel
    if texture.GetDrawLayer then layer, sublevel = texture:GetDrawLayer() end

    return ("%s %s alpha=%s texture=%s atlas=%s layer=%s:%s"):format(
        name,
        shown,
        tostring(alpha),
        tostring(path),
        tostring(atlas),
        tostring(layer),
        tostring(sublevel)
    )
end

function EncounterJournalSkin:Debug()
    NSkin:Print(("journal initialized=%s hookedScrollBox=%s lastTabID=%s refreshPending=%s refreshPasses=%d concealed=%s"):format(
        tostring(initialized),
        tostring(hookedScrollBox),
        tostring(lastTabID),
        tostring(refreshPending),
        refreshPasses,
        tostring(concealedScrollBox ~= nil)
    ))

    local journal = _G.EncounterJournal
    local instanceSelect = journal and journal.instanceSelect
    local scrollBox = instanceSelect and instanceSelect.ScrollBox
    if not scrollBox then
        NSkin:Print("journal debug: EncounterJournal.instanceSelect.ScrollBox is unavailable.")
        return
    end
    if not scrollBox.GetFrames then
        NSkin:Print("journal debug: ScrollBox:GetFrames is unavailable.")
        return
    end

    local frames = scrollBox:GetFrames()
    NSkin:Print(("journal shown=%s instanceSelectShown=%s frames=%d"):format(
        tostring(journal:IsShown()),
        tostring(instanceSelect:IsShown()),
        #frames
    ))

    for i = 1, #frames do
        local button = frames[i]
        local label = button.name and button.name:GetText() or "<no label>"

        local data = NSkin:GetSkinData(button, ENCOUNTER_JOURNAL_STATE, false)
        local border = NSkin:GetPixelBorder(button, "__NSkinEncounterBorder")
        local hover = data and data.encounterHover
        print(("|cff33aaffNSkin journal card %d:|r %s styledBorder=%s hoverShown=%s"):format(
            i,
            tostring(label),
            tostring(border ~= nil),
            tostring(hover and hover:IsShown())
        ))
        print("  normal:", DescribeTexture(button:GetNormalTexture()))
        print("  pushed:", DescribeTexture(button:GetPushedTexture()))
        print("  highlight:", DescribeTexture(button:GetHighlightTexture()))
        if button.GetDisabledTexture then
            print("  disabled:", DescribeTexture(button:GetDisabledTexture()))
        end

        if i <= 2 and button.GetRegions then
            local regions = { button:GetRegions() }
            print(("  direct regions (%d):"):format(#regions))
            for regionIndex = 1, #regions do
                local region = regions[regionIndex]
                if region and region.IsObjectType and region:IsObjectType("Texture") then
                    print(("    [%d] %s"):format(regionIndex, DescribeTexture(region)))
                elseif region and region.IsObjectType and region:IsObjectType("FontString") then
                    local name = region.GetName and region:GetName() or "<unnamed>"
                    print(("    [%d] FontString %s text=%s"):format(
                        regionIndex,
                        tostring(name),
                        tostring(region:GetText())
                    ))
                end
            end
        end
    end
end

NSkin:RegisterWindowSkin({
    module = "EncounterJournal",
    addon = "Blizzard_EncounterJournal",
    prepare = function()
        if _G.EventRegistry and _G.EventRegistry.RegisterCallback then
            _G.EventRegistry:RegisterCallback(
                "EncounterJournal.TabSet",
                EncounterJournalSkin.OnTabSet,
                EncounterJournalSkin
            )
        end
    end,
    apply = function() return EncounterJournalSkin:Initialize() end,
})
