local _, NSkin = ...

local AchievementsSkin = NSkin:NewModule("Achievements")

local IDs = {
    Scope = "Achievements",
    Window = "Achievements.Window",
    HeaderControls = "Achievements.HeaderControls",
    BottomTabs = "Achievements.BottomTabs",
    SearchBox = "Achievements.SearchBox",
    FilterDropdown = "Achievements.FilterDropdown",
    BackButton = "Achievements.BackButton",
    AchievementsScrollBar = "Achievements.AchievementsScrollBar",
    CategoryCards = "Achievements.CategoryCards",
    SummaryProgressBars = "Achievements.SummaryProgressBars",
}

local initialized = false
local applyPending = false
local lifecycleHooked = false
local tabsRegistered = false
local categoryCardsRegistered = false
local progressBarsRegistered = false
local categoryScrollBoxHooked = false
local concealedWindowArtwork = setmetatable({}, { __mode = "k" })
local hookedTabs = setmetatable({}, { __mode = "k" })

local PROGRESS_BAR_STYLE = {
    stripArtwork = true,
    useAppearanceTexture = true,
    background = true,
}

NSkin:RegisterAppearanceScope(IDs.Scope, {
    label = "Achievements",
})

local function IsVisible(frame)
    return frame and frame.IsVisible and frame:IsVisible() or false
end

local function QueueApply()
    if applyPending then return end
    applyPending = true
    C_Timer.After(0, function()
        applyPending = false
        AchievementsSkin:Apply()
    end)
end

local function GetBottomTabs(frame)
    return {
        frame and frame.Tab1 or _G.AchievementFrameTab1,
        frame and frame.Tab2 or _G.AchievementFrameTab2,
        frame and frame.Tab3 or _G.AchievementFrameTab3,
    }
end

local function GetCategoryScrollBox(frame)
    local categories = frame and frame.Categories
    return categories and categories.ScrollBox
end

local function GetCategoryButton(categoryFrame)
    return categoryFrame and categoryFrame.Button
end

local function GetCategoryArtwork(button)
    if not button then return {} end
    return {
        button.Background,
        button.GetHighlightTexture and button:GetHighlightTexture(),
    }
end

local function GetVisibleCategoryCards(frame)
    local cards = {}
    local scrollBox = GetCategoryScrollBox(frame)
    NSkin:ForEachScrollBoxFrame(scrollBox, function(categoryFrame)
        local button = GetCategoryButton(categoryFrame)
        if IsVisible(button) then cards[#cards + 1] = button end
    end)
    return cards
end

local function GetSummaryProgressBars()
    local bars = {}
    local total = _G.AchievementFrameSummaryCategoriesStatusBar
    if total then bars[#bars + 1] = total end
    for index = 1, 12 do
        local bar = _G["AchievementFrameSummaryCategoriesCategory" .. index]
        if bar then bars[#bars + 1] = bar end
    end
    return bars
end

local function GetVisibleSummaryProgressBars()
    local bars = {}
    for _, bar in ipairs(GetSummaryProgressBars()) do
        if IsVisible(bar) then bars[#bars + 1] = bar end
    end
    return bars
end

local function ConcealProgressBarHighlight(bar)
    local name = bar and bar.GetName and bar:GetName()
    local button = bar and bar.Button
        or name and _G[name .. "Button"]
    local highlight = button and button.Highlight
        or name and _G[name .. "ButtonHighlight"]
    NSkin:HideTextureRegions(highlight)
end

function AchievementsSkin:ApplyWindowChrome(frame)
    if not frame then return false end

    if not concealedWindowArtwork[frame] then
        NSkin:HideTextureRegions(frame)
        NSkin:HideTextureRegions(frame.Header)
        NSkin:HideTextureRegions(frame.HeaderDetails)
        NSkin:ConcealWindowArtwork(frame.Categories)
        concealedWindowArtwork[frame] = true
    end

    local title = frame.Header and frame.Header.Title
    local closeButton = frame.CloseButton or _G.AchievementFrameCloseButton
    local chrome = NSkin:SkinStandardWindowChrome({
        frame = frame,
        appearanceWindowID = IDs.Scope,
        elementID = IDs.Window,
        headerControlsID = IDs.HeaderControls,
        title = title,
        closeButton = closeButton,
    })
    if title and chrome and chrome.header then
        title:ClearAllPoints()
        title:SetPoint("CENTER", chrome.header, "CENTER", 0, 0)
    end

    local points = frame.Header and frame.Header.Points
    if points and closeButton and chrome and chrome.style then
        points:ClearAllPoints()
        points:SetPoint("RIGHT", closeButton, "LEFT", -8, 0)
        points:SetTextColor(unpack(
            NSkin:GetResolvedAppearanceColor(chrome.style.header, "text")))
        NSkin:ApplyResolvedTypography(points, chrome.style.header)
    end

    NSkin:RegisterSkinningElement(IDs.Window, {
        label = "Achievements window",
        kind = "WINDOW",
        module = "Achievements",
        appearanceWindowID = IDs.Scope,
        window = frame,
        target = frame,
        priority = 0,
        draggable = false,
    })
    return true
end

function AchievementsSkin:ApplyBottomTabs(frame)
    if not frame then return false end
    local tabs = GetBottomTabs(frame)
    for index = 1, #tabs do
        if not tabs[index] then return false end
    end

    local style = NSkin:GetAppearanceStyle(
        "tab", IDs.Scope, IDs.BottomTabs)
    local border = NSkin:GetAppearanceBorderColor(
        "tab", style, IDs.Scope, IDs.BottomTabs)
    local selected = _G.PanelTemplates_GetSelectedTab
        and _G.PanelTemplates_GetSelectedTab(frame)
    for index = 1, #tabs do
        local tab = tabs[index]
        NSkin:SkinTab(tab, index == selected, style, border)
        if not hookedTabs[tab] and tab.HookScript then
            tab:HookScript("OnClick", QueueApply)
            hookedTabs[tab] = true
        end
    end

    if not tabsRegistered then
        tabsRegistered = NSkin:RegisterTabGroup(IDs.BottomTabs, {
            label = "Achievements bottom tabs",
            kind = "TAB_GROUP",
            module = "Achievements",
            appearanceWindowID = IDs.Scope,
            window = frame,
            tabs = tabs,
            priority = 50,
            orientation = "HORIZONTAL",
            edge = "BOTTOM",
        }) == true
    end
    NSkin:ApplyTabGroupLayout(IDs.BottomTabs)
    return true
end

function AchievementsSkin:ApplyHeaderControls(frame)
    local headerDetails = frame and frame.HeaderDetails
    local filters = headerDetails and headerDetails.Filters
    local searchBox = filters and filters.SearchBox
    local filterDropdown = filters and filters.FilterDropdown
    local backButton = headerDetails and headerDetails.Back
    local applied = NSkin:RegisterSearchBox({
        id = IDs.SearchBox,
        module = "Achievements",
        appearanceWindowID = IDs.Scope,
        label = "Achievements search bar",
        window = frame,
        target = searchBox,
        priority = 60,
        highlightRegions = { searchBox },
        isEditable = function()
            return IsVisible(frame) and IsVisible(searchBox)
        end,
    }) ~= nil
    applied = NSkin:RegisterDropdown({
        id = IDs.FilterDropdown,
        module = "Achievements",
        appearanceWindowID = IDs.Scope,
        label = "Achievements filter dropdown",
        window = frame,
        target = filterDropdown,
        menus = { "MENU_ACHIEVEMENT_FILTER" },
        priority = 61,
        highlightRegions = { filterDropdown },
        isEditable = function()
            return IsVisible(frame) and IsVisible(filterDropdown)
        end,
    }) ~= nil or applied
    applied = NSkin:RegisterActionButton({
        id = IDs.BackButton,
        module = "Achievements",
        appearanceWindowID = IDs.Scope,
        label = "Achievements back button",
        window = frame,
        target = backButton,
        priority = 62,
        highlightRegions = { backButton },
        isEditable = function()
            return IsVisible(frame) and IsVisible(backButton)
        end,
    }) ~= nil or applied
    return applied
end

function AchievementsSkin:ApplyAchievementsScrollBar(frame)
    local achievements = frame and frame.Achievements
        or _G.AchievementFrameAchievements
    local scrollBar = achievements and achievements.ScrollBar
    if not frame or not achievements or not scrollBar then return false end

    return NSkin:RegisterScrollBar({
        id = IDs.AchievementsScrollBar,
        module = "Achievements",
        appearanceWindowID = IDs.Scope,
        label = "Achievements list scroll bar",
        window = frame,
        target = scrollBar,
        priority = 65,
        highlightRegions = { scrollBar },
        isEditable = function()
            return IsVisible(frame) and IsVisible(achievements)
                and IsVisible(scrollBar)
        end,
    }) ~= nil
end

function AchievementsSkin:StyleCategoryCard(categoryFrame)
    local button = GetCategoryButton(categoryFrame)
    if not button then return false end

    local style = NSkin:GetAppearanceStyle(
        "sectionCard", IDs.Scope, IDs.CategoryCards)
    local border = NSkin:GetAppearanceBorderColor(
        "sectionCard", style, IDs.Scope, IDs.CategoryCards)
    NSkin:SkinSectionCard(button, {
        style = style,
        border = border,
        collapsible = false,
        height = 0,
        preserveTextLayout = true,
        textRegion = button.Label,
        artworkRegions = GetCategoryArtwork(button),
    })
    if categoryCardsRegistered then
        NSkin:NotifySkinningElementBoundsChanged(IDs.CategoryCards)
    end
    return true
end

function AchievementsSkin:ApplyCategoryCards(frame)
    local scrollBox = GetCategoryScrollBox(frame)

    local applied = false
    if not NSkin:ForEachScrollBoxFrame(scrollBox, function(categoryFrame)
        applied = self:StyleCategoryCard(categoryFrame) or applied
    end) then return false end

    if not categoryCardsRegistered then
        categoryCardsRegistered = NSkin:RegisterSkinningElement(
            IDs.CategoryCards, {
                module = "Achievements",
                appearanceWindowID = IDs.Scope,
                label = "Achievement category cards",
                kind = "SECTION_CARD",
                window = frame,
                target = scrollBox,
                priority = 70,
                draggable = false,
                highlightRegions = function()
                    return GetVisibleCategoryCards(frame)
                end,
                editorOptions = {
                    { id = "shared.sectionCardAppearance",
                        label = "Section cards", category = "CUSTOMIZE" },
                },
                isEditable = function()
                    return IsVisible(frame) and IsVisible(frame.Categories)
                        and #GetVisibleCategoryCards(frame) > 0
                end,
            }) == true
    end
    if categoryCardsRegistered then
        NSkin:NotifySkinningElementBoundsChanged(IDs.CategoryCards)
    end
    return applied or categoryCardsRegistered
end

function AchievementsSkin:HookCategoryScrollBox(frame)
    local scrollBox = GetCategoryScrollBox(frame)
    if not scrollBox or categoryScrollBoxHooked then return false end

    local events = _G.ScrollBoxListMixin and _G.ScrollBoxListMixin.Event
    if scrollBox.RegisterCallback and events
        and events.OnInitializedFrame
    then
        scrollBox:RegisterCallback(events.OnInitializedFrame,
            function(_, categoryFrame)
                AchievementsSkin:StyleCategoryCard(categoryFrame)
            end, self)
        categoryScrollBoxHooked = true
    elseif _G.hooksecurefunc and type(scrollBox.Update) == "function" then
        _G.hooksecurefunc(scrollBox, "Update", function()
            AchievementsSkin:ApplyCategoryCards(frame)
        end)
        categoryScrollBoxHooked = true
    end
    return categoryScrollBoxHooked
end

function AchievementsSkin:ApplyProgressBars(frame)
    local summary = frame and frame.Summary
        or _G.AchievementFrameSummary
    local categories = summary and summary.Categories
        or _G.AchievementFrameSummaryCategories
    local bars = GetSummaryProgressBars()
    if not summary or not categories or #bars == 0 then return false end

    for _, bar in ipairs(bars) do
        NSkin:SkinProgressBar(bar, PROGRESS_BAR_STYLE)
        ConcealProgressBarHighlight(bar)
    end

    if not progressBarsRegistered then
        progressBarsRegistered = NSkin:RegisterProgressBarElement({
            id = IDs.SummaryProgressBars,
            module = "Achievements",
            appearanceWindowID = IDs.Scope,
            label = "Achievement summary progress bars",
            window = frame,
            target = categories,
            priority = 80,
            draggable = false,
            skinOptions = PROGRESS_BAR_STYLE,
            highlightRegions = GetVisibleSummaryProgressBars,
            isEditable = function()
                return IsVisible(frame) and IsVisible(summary)
                    and #GetVisibleSummaryProgressBars() > 0
            end,
        }) ~= nil
    end
    if progressBarsRegistered then
        NSkin:NotifySkinningElementBoundsChanged(IDs.SummaryProgressBars)
    end
    return true
end

function AchievementsSkin:Apply()
    local frame = _G.AchievementFrame
    if not frame then return false end

    self:ApplyWindowChrome(frame)
    self:ApplyBottomTabs(frame)
    self:ApplyHeaderControls(frame)
    self:ApplyAchievementsScrollBar(frame)
    self:ApplyCategoryCards(frame)
    self:ApplyProgressBars(frame)
    return true
end

function AchievementsSkin:Initialize()
    local frame = _G.AchievementFrame
    if not frame then return false end

    if not lifecycleHooked then
        if frame.HookScript then frame:HookScript("OnShow", QueueApply) end
        if _G.hooksecurefunc then
            for _, functionName in ipairs({
                "AchievementFrame_UpdateTabs",
                "AchievementFrameCategories_UpdateDataProvider",
                "AchievementFrameSummary_Update",
            }) do
                if type(_G[functionName]) == "function" then
                    _G.hooksecurefunc(functionName, QueueApply)
                end
            end
        end
        lifecycleHooked = true
    end

    initialized = true
    self:HookCategoryScrollBox(frame)
    self:Apply()
    if frame:IsShown() then QueueApply() end
    return true
end

function AchievementsSkin:RefreshAppearance()
    if initialized then self:Apply() end
end

NSkin:RegisterWindowSkin({
    module = "Achievements",
    addon = "Blizzard_AchievementUI",
    apply = function() return AchievementsSkin:Initialize() end,
})
