local _, NSkin = ...

local CooldownManagerSkin = NSkin:NewModule("CooldownManager")

local IDs = {
    Scope = "CooldownManager",
    Window = "CooldownManager.Window",
    HeaderControls = "CooldownManager.HeaderControls",
    SearchBox = "CooldownManager.SearchBox",
    SideTabs = "CooldownManager.SideTabs",
    LayoutDropdown = "CooldownManager.LayoutDropdown",
    RevertButton = "CooldownManager.RevertButton",
    HeaderCards = "CooldownManager.HeaderCards",
    GroupBuffHeaderCards = "CooldownManager.GroupBuffHeaderCards",
}

local initialized = false
local applyPending = false
local lifecycleHooked = false
local headerCardsRegistered = false
local groupBuffHeaderCardsRegistered = false
local concealedWindowArtwork = setmetatable({}, { __mode = "k" })
local headerArtwork = setmetatable({}, { __mode = "k" })
local hookedHeaders = setmetatable({}, { __mode = "k" })

NSkin:RegisterAppearanceScope(IDs.Scope, {
    label = "Cooldown Manager",
})

local function IsVisible(frame)
    return frame and frame.IsVisible and frame:IsVisible() or false
end

local function QueueApply()
    if applyPending then return end
    applyPending = true
    C_Timer.After(0, function()
        applyPending = false
        CooldownManagerSkin:Apply()
    end)
end

local function GetSideTabs(frame)
    local tabs = {}
    for _, tab in ipairs(frame and frame.TabButtons or {}) do
        if tab then tabs[#tabs + 1] = tab end
    end
    return tabs
end

local function ForEachCategory(frame, callback)
    local pool = frame and frame.categoryPool
    if not pool or type(pool.EnumerateActive) ~= "function" then return end
    for category in pool:EnumerateActive() do
        if category and category.Header then callback(category, category.Header) end
    end
end

local function GetVisibleHeaderCards(frame)
    local cards = {}
    ForEachCategory(frame, function(_, header)
        if IsVisible(header) then cards[#cards + 1] = header end
    end)
    return cards
end

local function ForEachGroupBuffSection(frame, callback)
    local filter = frame and frame.GroupBuffFilter
    if not filter then return end
    local function Apply(section)
        if section and section.Header then callback(section, section.Header) end
    end
    Apply(filter.shownSection)
    Apply(filter.hiddenSection)
end

local function GetVisibleGroupBuffHeaderCards(frame)
    local cards = {}
    ForEachGroupBuffSection(frame, function(_, header)
        if IsVisible(header) then cards[#cards + 1] = header end
    end)
    return cards
end

local function GetHeaderText(header)
    if header and type(header.GetTitleRegion) == "function" then
        local ok, title = pcall(header.GetTitleRegion, header)
        if ok and title then return title end
    end
    return header and (header.Name or header.Text)
end

local function GetHeaderExpanded(header)
    local category = header and header.GetParent and header:GetParent()
    if not category then return nil end
    local collapsed = category.isCollapsed
    if type(category.IsCollapsed) == "function" then
        local ok, value = pcall(category.IsCollapsed, category)
        if not ok then return nil end
        collapsed = value
    end
    -- Blizzard represents the initial expanded state as nil.
    return collapsed ~= true
end

local function CaptureHeaderArtwork(header)
    local artwork = headerArtwork[header]
    if artwork then return artwork end

    artwork = {}
    if header and header.GetRegions then
        for _, region in ipairs({ header:GetRegions() }) do
            if region.GetObjectType and region:GetObjectType() == "Texture" then
                artwork[#artwork + 1] = region
            end
        end
    end
    headerArtwork[header] = artwork
    return artwork
end

local function SuppressHeaderArtwork(header)
    for _, region in ipairs(CaptureHeaderArtwork(header)) do
        if region.SetAlpha then region:SetAlpha(0) end
        if region.Hide then region:Hide() end
    end
end

local function HookHeaderArtwork(header)
    if not header or hookedHeaders[header] then return end
    if header.HookScript then
        for _, script in ipairs({ "OnShow", "OnEnter", "OnLeave" }) do
            header:HookScript(script, SuppressHeaderArtwork)
        end
    end
    if _G.hooksecurefunc and type(header.UpdateCollapsedState) == "function" then
        pcall(_G.hooksecurefunc, header, "UpdateCollapsedState",
            SuppressHeaderArtwork)
    end
    hookedHeaders[header] = true
    SuppressHeaderArtwork(header)
end

function CooldownManagerSkin:ApplyWindowChrome(frame)
    if not frame then return false end

    if not concealedWindowArtwork[frame] then
        NSkin:HideTextureRegions(frame)
        NSkin:ConcealWindowArtwork(frame.Inset)
        concealedWindowArtwork[frame] = true
    end

    NSkin:SkinStandardWindowChrome({
        frame = frame,
        appearanceWindowID = IDs.Scope,
        elementID = IDs.Window,
        headerControlsID = IDs.HeaderControls,
        title = frame.TitleContainer and frame.TitleContainer.TitleText,
    })
    NSkin:RegisterSkinningElement(IDs.Window, {
        label = "Cooldown Settings window",
        kind = "WINDOW",
        module = "CooldownManager",
        appearanceWindowID = IDs.Scope,
        window = frame,
        target = frame,
        priority = 0,
        draggable = false,
    })
    return true
end

function CooldownManagerSkin:ApplySearchBox(frame)
    local searchBox = frame and frame.SearchBox
    if not searchBox then return false end
    return NSkin:RegisterSearchBox({
        id = IDs.SearchBox,
        module = "CooldownManager",
        appearanceWindowID = IDs.Scope,
        label = "Cooldown search bar",
        window = frame,
        target = searchBox,
        priority = 50,
        highlightRegions = { searchBox },
        isEditable = function()
            return IsVisible(frame) and IsVisible(searchBox)
        end,
    }) ~= nil
end

function CooldownManagerSkin:ApplySideTabs(frame)
    local tabs = GetSideTabs(frame)
    if #tabs == 0 then return false end
    return NSkin:RegisterSideTabGroup(IDs.SideTabs, {
        module = "CooldownManager",
        appearanceWindowID = IDs.Scope,
        label = "Cooldown Settings side tabs",
        window = frame,
        targets = tabs,
        priority = 55,
        isEditable = function()
            if not IsVisible(frame) then return false end
            for i = 1, #tabs do
                if IsVisible(tabs[i]) then return true end
            end
            return false
        end,
    }) ~= nil
end

function CooldownManagerSkin:ApplyFooterControls(frame)
    if not frame then return false end
    local layoutDropdown = frame.LayoutDropdown
    local revertButton = frame.UndoButton
    local applied = NSkin:RegisterDropdown({
        id = IDs.LayoutDropdown,
        module = "CooldownManager",
        appearanceWindowID = IDs.Scope,
        label = "Cooldown layout dropdown",
        window = frame,
        target = layoutDropdown,
        menus = { "MENU_COOLDOWN_SETTINGS_LAYOUTS" },
        priority = 60,
        highlightRegions = { layoutDropdown },
        isEditable = function()
            return IsVisible(frame) and IsVisible(layoutDropdown)
        end,
    }) ~= nil
    applied = NSkin:RegisterActionButton({
        id = IDs.RevertButton,
        module = "CooldownManager",
        appearanceWindowID = IDs.Scope,
        label = "Revert cooldown layout button",
        window = frame,
        target = revertButton,
        priority = 61,
        highlightRegions = { revertButton },
        isEditable = function()
            return IsVisible(frame) and IsVisible(revertButton)
        end,
    }) ~= nil or applied
    return applied
end

function CooldownManagerSkin:ApplyHeaderCards(frame)
    local pool = frame and frame.categoryPool
    local content = frame and frame.CooldownScroll
        and frame.CooldownScroll.Content
    if not frame or not pool or not content then return false end

    local style = NSkin:GetAppearanceStyle(
        "sectionCard", IDs.Scope, IDs.HeaderCards)
    local border = NSkin:GetAppearanceBorderColor(
        "sectionCard", style, IDs.Scope, IDs.HeaderCards)
    local applied = false
    ForEachCategory(frame, function(_, header)
        local artwork = CaptureHeaderArtwork(header)
        NSkin:SkinSectionCard(header, {
            style = style,
            border = border,
            collapsible = true,
            height = 0,
            getExpanded = GetHeaderExpanded,
            textRegion = GetHeaderText(header),
            artworkRegions = artwork,
        })
        HookHeaderArtwork(header)
        applied = true
    end)

    if not headerCardsRegistered then
        headerCardsRegistered = NSkin:RegisterSkinningElement(
            IDs.HeaderCards, {
                module = "CooldownManager",
                appearanceWindowID = IDs.Scope,
                label = "Cooldown category header cards",
                kind = "SECTION_CARD",
                window = frame,
                target = content,
                priority = 70,
                draggable = false,
                highlightRegions = function()
                    return GetVisibleHeaderCards(frame)
                end,
                editorOptions = {
                    { id = "shared.sectionCardAppearance",
                        label = "Section cards", category = "CUSTOMIZE" },
                },
                isEditable = function()
                    return IsVisible(frame)
                        and #GetVisibleHeaderCards(frame) > 0
                end,
            }) == true
    end
    if headerCardsRegistered then
        NSkin:NotifySkinningElementBoundsChanged(IDs.HeaderCards)
    end
    return applied or headerCardsRegistered
end

function CooldownManagerSkin:ApplyGroupBuffHeaderCards(frame)
    local filter = frame and frame.GroupBuffFilter
    local content = filter and filter.Scroll and filter.Scroll.Content
    if not frame or not filter or not content then return false end

    local style = NSkin:GetAppearanceStyle(
        "sectionCard", IDs.Scope, IDs.GroupBuffHeaderCards)
    local border = NSkin:GetAppearanceBorderColor(
        "sectionCard", style, IDs.Scope, IDs.GroupBuffHeaderCards)
    local applied = false
    ForEachGroupBuffSection(frame, function(_, header)
        local artwork = CaptureHeaderArtwork(header)
        NSkin:SkinSectionCard(header, {
            style = style,
            border = border,
            collapsible = true,
            height = 0,
            getExpanded = GetHeaderExpanded,
            textRegion = GetHeaderText(header),
            artworkRegions = artwork,
        })
        HookHeaderArtwork(header)
        applied = true
    end)

    if not groupBuffHeaderCardsRegistered then
        groupBuffHeaderCardsRegistered = NSkin:RegisterSkinningElement(
            IDs.GroupBuffHeaderCards, {
                module = "CooldownManager",
                appearanceWindowID = IDs.Scope,
                label = "Group buff header cards",
                kind = "SECTION_CARD",
                window = frame,
                target = content,
                priority = 71,
                draggable = false,
                highlightRegions = function()
                    return GetVisibleGroupBuffHeaderCards(frame)
                end,
                editorOptions = {
                    { id = "shared.sectionCardAppearance",
                        label = "Section cards", category = "CUSTOMIZE" },
                },
                isEditable = function()
                    return IsVisible(frame) and IsVisible(filter)
                        and #GetVisibleGroupBuffHeaderCards(frame) > 0
                end,
            }) == true
    end
    if groupBuffHeaderCardsRegistered then
        NSkin:NotifySkinningElementBoundsChanged(IDs.GroupBuffHeaderCards)
    end
    return applied or groupBuffHeaderCardsRegistered
end

function CooldownManagerSkin:Apply()
    local frame = _G.CooldownViewerSettings
    if not frame then return false end
    self:ApplyWindowChrome(frame)
    self:ApplySearchBox(frame)
    self:ApplySideTabs(frame)
    self:ApplyFooterControls(frame)
    self:ApplyHeaderCards(frame)
    self:ApplyGroupBuffHeaderCards(frame)
    return true
end

function CooldownManagerSkin:Initialize()
    local frame = _G.CooldownViewerSettings
    if not frame then return false end

    if not lifecycleHooked then
        if frame.HookScript then frame:HookScript("OnShow", QueueApply) end
        if _G.hooksecurefunc and type(frame.RefreshLayout) == "function" then
            _G.hooksecurefunc(frame, "RefreshLayout", QueueApply)
        end
        lifecycleHooked = true
    end
    initialized = true
    self:Apply()
    if frame:IsShown() then QueueApply() end
    return true
end

function CooldownManagerSkin:RefreshAppearance()
    if initialized then self:Apply() end
end

NSkin:RegisterWindowSkin({
    module = "CooldownManager",
    addon = "Blizzard_CooldownViewer",
    apply = function() return CooldownManagerSkin:Initialize() end,
})
