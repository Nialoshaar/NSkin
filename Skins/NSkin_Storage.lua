local _, NSkin = ...

local StorageSkin = NSkin:NewModule("Storage")

local IDs = {
    Scope = "Storage",
    Window = "Storage.CombinedBags.Window",
    HeaderControls = "Storage.CombinedBags.HeaderControls",
    SearchBox = "Storage.CombinedBags.SearchBox",
    CleanupButton = "Storage.CombinedBags.CleanupButton",
    GoldText = "Storage.CombinedBags.GoldText",
    SilverText = "Storage.CombinedBags.SilverText",
    CombinedItems = "Storage.CombinedBags.Items",
    IndividualWindow = "Storage.ContainerFrame6.Window",
    IndividualHeaderControls = "Storage.ContainerFrame6.HeaderControls",
    IndividualItems = "Storage.ContainerFrame6.Items",
    BankWindow = "Storage.Bank.Window",
    BankHeaderControls = "Storage.Bank.HeaderControls",
    BankSearchBox = "Storage.Bank.SearchBox",
    BankCleanupButton = "Storage.Bank.CleanupButton",
    BankAutoDepositButton = "Storage.Bank.AutoDepositButton",
    BankIncludeReagentsCheckbox = "Storage.Bank.IncludeReagentsCheckbox",
    BankWithdrawButton = "Storage.Bank.WithdrawButton",
    BankDepositButton = "Storage.Bank.DepositButton",
    BankHeaderText = "Storage.Bank.HeaderText",
    BankPurchasePrompt = "Storage.Bank.PurchasePrompt",
    BankPurchasePromptTitle = "Storage.Bank.PurchasePrompt.Title",
    BankPurchasePromptText = "Storage.Bank.PurchasePrompt.PromptText",
    BankPurchasePromptTabCost = "Storage.Bank.PurchasePrompt.TabCost",
    BankPurchasePromptGoldText = "Storage.Bank.PurchasePrompt.GoldText",
    BankPurchasePromptSilverText = "Storage.Bank.PurchasePrompt.SilverText",
    BankPurchasePromptCopperText = "Storage.Bank.PurchasePrompt.CopperText",
    BankPurchasePromptButton = "Storage.Bank.PurchasePrompt.PurchaseButton",
    BankBottomTabs = "Storage.Bank.BottomTabs",
    BankSideTabs = "Storage.Bank.SideTabs",
    BankItems = "Storage.Bank.Items",
    BankGoldText = "Storage.Bank.GoldText",
    BankSilverText = "Storage.Bank.SilverText",
    BankCopperText = "Storage.Bank.CopperText",
}

local initialized = false
local tokenLifecycleHooked = false
local containerShowHooks = setmetatable({}, { __mode = "k" })
local containerItemHooks = setmetatable({}, { __mode = "k" })
local containerCurrencyHooks = setmetatable({}, { __mode = "k" })
local registeredItemGroups = {}
local bankLifecycleHooked = false
local bankBottomTabsRegistered = false
local bankPurchasePromptRegistered = false
local INDIVIDUAL_CONTAINER_FRAME_COUNT = 6

NSkin:RegisterAppearanceScope(IDs.Scope, {
    label = "Storage",
})

local function IsVisible(frame)
    return frame and frame.IsVisible and frame:IsVisible() or false
end

local function CompactRegions(...)
    local regions = {}
    for index = 1, select("#", ...) do
        local region = select(index, ...)
        if region then regions[#regions + 1] = region end
    end
    return regions
end

local function GetDirectRegions(frame)
    if not frame or type(frame.GetRegions) ~= "function" then return {} end
    return CompactRegions(frame:GetRegions())
end

local function AppendRegions(target, source)
    for _, region in ipairs(source or {}) do
        target[#target + 1] = region
    end
end

local function GetIndividualContainerFrameIDs(index)
    local prefix = "Storage.ContainerFrame" .. index
    if index == INDIVIDUAL_CONTAINER_FRAME_COUNT then
        return IDs.IndividualWindow, IDs.IndividualHeaderControls,
            IDs.IndividualItems, prefix .. ".GoldText",
            prefix .. ".SilverText"
    end
    return prefix .. ".Window", prefix .. ".HeaderControls",
        prefix .. ".Items", prefix .. ".GoldText",
        prefix .. ".SilverText"
end

local function GetIndividualContainerFrames()
    local frames = {}
    for index = 1, INDIVIDUAL_CONTAINER_FRAME_COUNT do
        local frame = _G["ContainerFrame" .. index]
        if frame then
            frames[#frames + 1] = { index = index, frame = frame }
        end
    end
    return frames
end

local function SetDecorationsSuppressed(owner, key, regions, suppressed)
    if not owner then return end
    local data = NSkin:GetSkinData(owner, "storageDecorations")
    data[key] = data[key] or { states = {} }
    local group = data[key]
    local active = {}
    if suppressed then
        for _, region in ipairs(regions or {}) do
            if region then active[region] = true end
        end
    end

    for region, state in pairs(group.states) do
        state.active = active[region] == true
        if not state.active then
            state.applying = true
            if region.SetAlpha then region:SetAlpha(state.alpha) end
            if state.shown ~= nil and region.SetShown then
                region:SetShown(state.shown)
            end
            state.applying = nil
        end
    end
    for region in pairs(active) do
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
            if not state.active or state.applying then return end
            state.applying = true
            if region.SetAlpha then region:SetAlpha(0) end
            state.applying = nil
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

local function GetCurrencyBorderRegions(container)
    local border = container and container.Border
    if not border then return {} end
    return { border.Left, border.Middle, border.Right }
end

local function GetMoneyText(moneyFrame, denomination)
    local button = moneyFrame and moneyFrame[denomination .. "Button"]
    return button and (button.Text or button.text)
end

local function GetCleanupButtonIcon(button)
    local data = NSkin:GetSkinData(button, "storageCleanupButton")
    if data.icon then return data.icon end

    local icon = button:CreateTexture(nil, "ARTWORK", nil, 1)
    icon:SetPoint("TOPLEFT", button, "TOPLEFT", 5, -5)
    icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -5, 5)
    NSkin:ConfigureOwnedPixelTexture(icon)
    icon:SetTexture(NSkin.mediaPath .. "broom.png")
    icon:SetVertexColor(1, 1, 1, 1)
    data.icon = icon
    return icon
end

local function SkinCleanupButton(_, button, style, borderColor)
    local icon = GetCleanupButtonIcon(button)
    NSkin:SkinFlatButton(button, nil, { 0, 0, 0, 0 }, borderColor,
        nil, nil, nil, icon)
    local background = NSkin:GetFlatBackground(button)
    if background then NSkin:SetOwnedTextureColor(background, 0, 0, 0, 0) end
    local border = NSkin:GetPixelBorder(button, "NSkinFlatBackgroundBorder")
    if border then NSkin:SetPixelBorderSize(border, 1) end
end

local function GetContainerItemButtons(frame, visibleOnly)
    local buttons = {}
    if not frame then return buttons end
    if type(frame.EnumerateValidItems) == "function" then
        for _, button in frame:EnumerateValidItems() do
            if button and (not visibleOnly or IsVisible(button)) then
                buttons[#buttons + 1] = button
            end
        end
    else
        for _, button in ipairs(frame.Items or {}) do
            if button and (not visibleOnly or IsVisible(button)) then
                buttons[#buttons + 1] = button
            end
        end
    end
    return buttons
end

local function GetContainerItemTexture(button)
    return button and (button.IconTexture or button.Icon or button.icon)
end

local function ContainerItemHasItem(button)
    if not button or not _G.C_Container
        or type(_G.C_Container.GetContainerItemInfo) ~= "function"
        or type(button.GetBagID) ~= "function"
        or type(button.GetID) ~= "function"
    then return false end
    return _G.C_Container.GetContainerItemInfo(
        button:GetBagID(), button:GetID()) ~= nil
end

local function UpdateContainerItemEmptyArtwork(button)
    local icon = GetContainerItemTexture(button)
    if not icon then return end
    local data = NSkin:GetSkinData(button, "storageEmptySlotArtwork")
    if data.icon ~= icon then
        data.icon = icon
        data.alpha = icon.GetAlpha and icon:GetAlpha() or 1
        if data.alpha == 0 then data.alpha = 1 end
        data.hooked = nil
    end

    data.empty = not ContainerItemHasItem(button)
    local function MaintainEmptyState()
        if not data.empty or data.applying then return end
        data.applying = true
        icon:SetAlpha(0)
        data.applying = nil
    end
    if not data.hooked and _G.hooksecurefunc
        and type(icon.SetAlpha) == "function" then
        pcall(_G.hooksecurefunc, icon, "SetAlpha", MaintainEmptyState)
        data.hooked = true
    end
    if data.empty then
        MaintainEmptyState()
    elseif data.wasEmpty then
        data.applying = true
        icon:SetAlpha(data.alpha or 1)
        data.applying = nil
    end
    data.wasEmpty = data.empty
end

local function GetContainerItemQuality(button)
    if not button or not _G.C_Container
        or type(_G.C_Container.GetContainerItemInfo) ~= "function"
        or type(button.GetBagID) ~= "function"
        or type(button.GetID) ~= "function"
    then return nil end
    local info = _G.C_Container.GetContainerItemInfo(
        button:GetBagID(), button:GetID())
    return info and info.quality
end

local function GetContainerItemDescriptors(frame)
    local descriptors = {}
    for _, button in ipairs(GetContainerItemButtons(frame, false)) do
        SetDecorationsSuppressed(button, "ItemSlotBackground",
            CompactRegions(button.ItemSlotBackground), true)
        UpdateContainerItemEmptyArtwork(button)
        descriptors[#descriptors + 1] = {
            target = button,
            textureProvider = GetContainerItemTexture,
            borderOwner = button,
            borderSize = 1,
            borderPadding = 0,
            qualityProvider = GetContainerItemQuality,
            hoverRegion = button.HighlightTexture
                or (button.GetHighlightTexture
                    and button:GetHighlightTexture()),
            nativeDecorationRegions = CompactRegions(
                button.ItemSlotBackground,
                button.NormalTexture
                    or (button.GetNormalTexture
                        and button:GetNormalTexture()),
                button.PushedTexture
                    or (button.GetPushedTexture
                        and button:GetPushedTexture()),
                button.IconBorder),
        }
    end
    return descriptors
end

function StorageSkin:ApplyWindowChrome(frame, elementID, headerControlsID, label)
    NSkin:SkinStandardWindowChrome({
        frame = frame,
        appearanceWindowID = IDs.Scope,
        elementID = elementID,
        headerControlsID = headerControlsID,
        title = frame.TitleContainer and frame.TitleContainer.TitleText,
    })
    NSkin:RegisterSkinningElement(elementID, {
        label = label,
        kind = "WINDOW",
        module = "Storage",
        appearanceWindowID = IDs.Scope,
        window = frame,
        target = frame,
        priority = 0,
        draggable = false,
    })
    return true
end

function StorageSkin:ApplyItemIcons(frame, id, label)
    if not frame then return false end
    if not registeredItemGroups[id] then
        registeredItemGroups[id] = NSkin:RegisterIconGroup({
            id = id,
            module = "Storage",
            appearanceWindowID = IDs.Scope,
            label = label,
            window = frame,
            target = frame,
            priority = 40,
            draggable = false,
            children = function()
                return GetContainerItemDescriptors(frame)
            end,
            highlightRegions = function()
                return GetContainerItemButtons(frame, true)
            end,
            pixelBorderTargets = function()
                return GetContainerItemButtons(frame, true)
            end,
            isEditable = function()
                return IsVisible(frame)
                    and #GetContainerItemButtons(frame, true) > 0
            end,
        }) ~= nil
    else
        NSkin:RefreshIconGroup(id)
    end
    return registeredItemGroups[id]
end

function StorageSkin:HookContainerFrame(frame, itemID, itemLabel)
    if not frame then return end
    if not containerShowHooks[frame] and frame.HookScript then
        frame:HookScript("OnShow", function()
            StorageSkin:Apply()
        end)
        containerShowHooks[frame] = true
    end
    if not containerItemHooks[frame] and _G.hooksecurefunc
        and type(frame.UpdateItems) == "function" then
        pcall(_G.hooksecurefunc, frame, "UpdateItems", function()
            StorageSkin:ApplyItemIcons(frame, itemID, itemLabel)
        end)
        containerItemHooks[frame] = true
    end
end

function StorageSkin:ApplyControls(frame)
    local searchBox = _G.BagItemSearchBox
    local cleanupButton = _G.BagItemAutoSortButton
    local applied = false
    if searchBox then
        applied = NSkin:RegisterSearchBox({
            id = IDs.SearchBox,
            module = "Storage",
            appearanceWindowID = IDs.Scope,
            label = "Combined Bags search box",
            window = frame,
            target = searchBox,
            priority = 20,
            highlightRegions = { searchBox },
            isEditable = function()
                return IsVisible(frame) and IsVisible(searchBox)
                    and searchBox:GetParent() == frame
            end,
        }) ~= nil or applied
    end
    if cleanupButton then
        applied = NSkin:RegisterTypedElement("BUTTON", {
            id = IDs.CleanupButton,
            module = "Storage",
            appearanceWindowID = IDs.Scope,
            label = "Clean up bags button",
            window = frame,
            target = cleanupButton,
            skinAdapter = SkinCleanupButton,
            priority = 21,
            highlightRegions = { cleanupButton },
            isEditable = function()
                return IsVisible(frame) and IsVisible(cleanupButton)
                    and cleanupButton:GetParent() == frame
            end,
        }) ~= nil or applied
    end
    return applied
end

function StorageSkin:ApplyCurrency(frame, goldID, silverID, labelPrefix)
    local moneyFrame = frame and frame.MoneyFrame
    if not moneyFrame then return false end
    goldID = goldID or IDs.GoldText
    silverID = silverID or IDs.SilverText
    labelPrefix = labelPrefix or "Combined Bags"
    SetDecorationsSuppressed(moneyFrame, "MoneyBorder",
        GetCurrencyBorderRegions(moneyFrame), true)

    local applied = false
    for index, definition in ipairs({
        { goldID, labelPrefix .. " gold", "Gold", "GOLD" },
        { silverID, labelPrefix .. " silver", "Silver" },
    }) do
        local id, label, denomination, numberFormat = unpack(definition)
        local text = GetMoneyText(moneyFrame, denomination)
        if text then
            applied = NSkin:RegisterTextElement({
                id = id,
                module = "Storage",
                appearanceWindowID = IDs.Scope,
                label = label,
                window = frame,
                target = text,
                priority = 30 + index,
                numberFormat = numberFormat,
                highlightRegions = { text },
                isEditable = function()
                    return IsVisible(frame) and IsVisible(text)
                end,
            }) ~= nil or applied
        end
    end
    return applied
end

function StorageSkin:ApplyTokenFrame()
    local tokenFrame = _G.BackpackTokenFrame
    if not tokenFrame then return false end
    SetDecorationsSuppressed(tokenFrame, "TokenBorder",
        GetCurrencyBorderRegions(tokenFrame), true)

    if not tokenLifecycleHooked and _G.hooksecurefunc
        and type(tokenFrame.SetIsCombinedInventory) == "function" then
        pcall(_G.hooksecurefunc, tokenFrame, "SetIsCombinedInventory", function()
            StorageSkin:ApplyTokenFrame()
        end)
        tokenLifecycleHooked = true
    end
    return true
end

function StorageSkin:HookContainerCurrency(frame, goldID, silverID, labelPrefix)
    if not frame or not _G.hooksecurefunc then return end
    local hooks = containerCurrencyHooks[frame]
    if not hooks then
        hooks = {}
        containerCurrencyHooks[frame] = hooks
    end
    for _, method in ipairs({ "UpdateCurrencyFrames", "UpdateMoneyFrame" }) do
        if not hooks[method] and type(frame[method]) == "function" then
            pcall(_G.hooksecurefunc, frame, method, function()
                StorageSkin:ApplyCurrency(
                    frame, goldID, silverID, labelPrefix)
                StorageSkin:ApplyTokenFrame()
            end)
            hooks[method] = true
        end
    end
end

local function GetBankBottomTabs(frame)
    local tabSystem = frame and frame.TabSystem
    if not tabSystem then return {} end

    local tabs = {}
    if type(frame.GetTabSet) == "function"
        and type(frame.GetTabButton) == "function" then
        local tabSet = frame:GetTabSet()
        for _, tabID in ipairs(tabSet or {}) do
            local tab = frame:GetTabButton(tabID)
            if tab then tabs[#tabs + 1] = tab end
        end
    end
    if #tabs == 0 then
        for _, tab in ipairs(tabSystem.tabs or {}) do
            if tab then tabs[#tabs + 1] = tab end
        end
    end
    return tabs
end

local function GetBankSideTabs(panel)
    local tabs = {}
    local pool = panel and panel.bankTabPool
    if pool and type(pool.EnumerateActive) == "function" then
        for tab in pool:EnumerateActive() do
            if tab then tabs[#tabs + 1] = tab end
        end
        table.sort(tabs, function(left, right)
            local leftID = tonumber(left.tabData and left.tabData.ID) or 0
            local rightID = tonumber(right.tabData and right.tabData.ID) or 0
            return leftID < rightID
        end)
    end
    if panel and panel.PurchaseTab then
        tabs[#tabs + 1] = panel.PurchaseTab
    end
    return tabs
end

local function GetBankTabIcon(tab)
    return tab and tab.Icon
end

local function GetBankTabDescriptors(panel)
    local descriptors = {}
    for _, tab in ipairs(GetBankSideTabs(panel)) do
        descriptors[#descriptors + 1] = {
            target = tab,
            textureProvider = GetBankTabIcon,
            borderOwner = tab,
            borderSize = 1,
            borderPadding = 0,
            hoverRegion = tab.HighlightTexture
                or (tab.GetHighlightTexture
                    and tab:GetHighlightTexture()),
            nativeDecorationRegions = CompactRegions(
                tab.Background,
                tab.Border,
                tab.SelectedTexture,
                tab.HighlightTexture
                    or (tab.GetHighlightTexture
                        and tab:GetHighlightTexture())),
        }
    end
    return descriptors
end

local function GetBankItemButtons(panel, visibleOnly)
    local buttons = {}
    if not panel or type(panel.EnumerateValidItems) ~= "function" then
        return buttons
    end
    for button in panel:EnumerateValidItems() do
        if button and (not visibleOnly or IsVisible(button)) then
            buttons[#buttons + 1] = button
        end
    end
    return buttons
end

local function GetBankItemQuality(button)
    return button and button.itemInfo and button.itemInfo.quality
end

local function GetBankItemDescriptors(panel)
    local descriptors = {}
    for _, button in ipairs(GetBankItemButtons(panel, false)) do
        SetDecorationsSuppressed(button, "BankItemBackground",
            CompactRegions(button.Background), true)
        descriptors[#descriptors + 1] = {
            target = button,
            textureProvider = GetContainerItemTexture,
            borderOwner = button,
            borderSize = 1,
            borderPadding = 0,
            qualityProvider = GetBankItemQuality,
            hoverRegion = button.HighlightTexture
                or (button.GetHighlightTexture
                    and button:GetHighlightTexture()),
            nativeDecorationRegions = CompactRegions(
                button.Background,
                button.HighlightTexture
                    or (button.GetHighlightTexture
                        and button:GetHighlightTexture()),
                button.NormalTexture
                    or (button.GetNormalTexture
                        and button:GetNormalTexture()),
                button.PushedTexture
                    or (button.GetPushedTexture
                        and button:GetPushedTexture()),
                button.IconBorder),
        }
    end
    return descriptors
end

function StorageSkin:ApplyBankControls(frame, panel)
    local searchBox = frame.BankItemSearchBox or _G.BankItemSearchBox
    local cleanupButton = panel and panel.AutoSortButton
    local autoDeposit = panel and panel.AutoDepositFrame
    local depositButton = autoDeposit and autoDeposit.DepositButton
    local includeReagents = autoDeposit
        and autoDeposit.IncludeReagentsCheckbox
    local headerText = panel and panel.Header and panel.Header.Text
    local applied = false

    if searchBox then
        applied = NSkin:RegisterSearchBox({
            id = IDs.BankSearchBox,
            module = "Storage",
            appearanceWindowID = IDs.Scope,
            label = "Bank search box",
            window = frame,
            target = searchBox,
            priority = 20,
            highlightRegions = { searchBox },
            isEditable = function()
                return IsVisible(frame) and IsVisible(searchBox)
            end,
        }) ~= nil or applied
    end
    if cleanupButton then
        applied = NSkin:RegisterTypedElement("BUTTON", {
            id = IDs.BankCleanupButton,
            module = "Storage",
            appearanceWindowID = IDs.Scope,
            label = "Clean up bank button",
            window = frame,
            target = cleanupButton,
            skinAdapter = SkinCleanupButton,
            priority = 21,
            highlightRegions = { cleanupButton },
            isEditable = function()
                return IsVisible(frame) and IsVisible(cleanupButton)
            end,
        }) ~= nil or applied
    end
    if depositButton then
        applied = NSkin:RegisterTypedElement("BUTTON", {
            id = IDs.BankAutoDepositButton,
            module = "Storage",
            appearanceWindowID = IDs.Scope,
            label = "Bank auto-deposit button",
            window = frame,
            target = depositButton,
            priority = 22,
            highlightRegions = { depositButton },
            isEditable = function()
                return IsVisible(frame) and IsVisible(depositButton)
            end,
        }) ~= nil or applied
    end
    if includeReagents then
        local includeReagentsText = includeReagents.Text
            or includeReagents.text
        local element = NSkin:RegisterCheckbox({
            id = IDs.BankIncludeReagentsCheckbox,
            module = "Storage",
            appearanceWindowID = IDs.Scope,
            label = "Include tradeable reagents",
            window = frame,
            target = includeReagents,
            text = includeReagentsText,
            getChecked = function(target)
                return target and target.GetChecked
                    and target:GetChecked() == true or false
            end,
            priority = 23,
            highlightRegions = {
                includeReagents,
                includeReagentsText,
            },
            isEditable = function()
                return IsVisible(frame) and IsVisible(includeReagents)
            end,
        })
        if element then NSkin:RefreshTypedElementAppearance(element) end
        applied = element ~= nil or applied
    end
    if headerText then
        applied = NSkin:RegisterTextElement({
            id = IDs.BankHeaderText,
            module = "Storage",
            appearanceWindowID = IDs.Scope,
            label = "Bank panel header",
            window = frame,
            target = headerText,
            priority = 24,
            highlightRegions = { headerText },
            isEditable = function()
                return IsVisible(frame) and IsVisible(headerText)
            end,
        }) ~= nil or applied
    end
    return applied
end

function StorageSkin:ApplyBankBottomTabs(frame)
    local tabSystem = frame and frame.TabSystem
    local tabs = GetBankBottomTabs(frame)
    if not tabSystem or #tabs == 0 then return false end

    local style = NSkin:GetAppearanceStyle(
        "tab", IDs.Scope, IDs.BankBottomTabs)
    local border = NSkin:GetAppearanceBorderColor(
        "tab", style, IDs.Scope, IDs.BankBottomTabs)
    for _, tab in ipairs(tabs) do
        local selected = tab.IsSelected and tab:IsSelected()
        NSkin:SkinTab(tab, selected, style, border)
    end

    if not bankBottomTabsRegistered then
        bankBottomTabsRegistered = NSkin:RegisterTabGroup(
            IDs.BankBottomTabs, {
                label = "Bank bottom tabs",
                kind = "TAB_GROUP",
                module = "Storage",
                appearanceWindowID = IDs.Scope,
                window = frame,
                target = tabSystem,
                tabs = tabs,
                priority = 50,
                orientation = "HORIZONTAL",
                edge = "BOTTOM",
                isEditable = function()
                    return IsVisible(frame) and IsVisible(tabSystem)
                end,
            }) == true
    end
    if bankBottomTabsRegistered then
        NSkin:ApplyTabGroupLayout(IDs.BankBottomTabs)
    end
    return bankBottomTabsRegistered
end

function StorageSkin:ApplyBankSideTabs(frame, panel)
    local tabs = GetBankSideTabs(panel)
    if #tabs == 0 then return false end
    if not registeredItemGroups[IDs.BankSideTabs] then
        registeredItemGroups[IDs.BankSideTabs] = NSkin:RegisterIconGroup({
            id = IDs.BankSideTabs,
            module = "Storage",
            appearanceWindowID = IDs.Scope,
            label = "Bank tab icons",
            window = frame,
            target = panel,
            priority = 55,
            draggable = false,
            children = function()
                return GetBankTabDescriptors(panel)
            end,
            highlightRegions = function()
                local visible = {}
                for _, tab in ipairs(GetBankSideTabs(panel)) do
                    if IsVisible(tab) then visible[#visible + 1] = tab end
                end
                return visible
            end,
            pixelBorderTargets = function()
                return GetBankSideTabs(panel)
            end,
            isEditable = function()
                if not IsVisible(frame) then return false end
                for _, tab in ipairs(GetBankSideTabs(panel)) do
                    if IsVisible(tab) then return true end
                end
                return false
            end,
        }) ~= nil
    else
        NSkin:RefreshIconGroup(IDs.BankSideTabs)
    end
    return registeredItemGroups[IDs.BankSideTabs]
end

function StorageSkin:ApplyBankPurchasePrompt(frame, panel)
    local prompt = panel and panel.PurchasePrompt
    local costFrame = prompt and prompt.TabCostFrame
    if not prompt or not costFrame then return false end

    local windowStyle = NSkin:GetAppearanceStyle(
        "window", IDs.Scope, IDs.BankPurchasePrompt)
    local surfaceStyle = {}
    for key, value in pairs(windowStyle or {}) do
        surfaceStyle[key] = value
    end
    surfaceStyle.borderSize = 1
    surfaceStyle.borderPadding = 0
    NSkin:SkinPopupSurface(prompt, {
        windowStyle = surfaceStyle,
        border = NSkin:GetAppearanceBorderColor(
            "window", windowStyle, IDs.Scope, IDs.BankPurchasePrompt),
        nativeDecorationRegions = CompactRegions(
            prompt.Background,
            prompt.TopInner,
            prompt.RightInner,
            prompt.LeftInner,
            prompt.BottomInner,
            prompt.TopLeftInner,
            prompt.TopRightInner,
            prompt.BottomLeftInner,
            prompt.BottomRightInner),
    })

    if not bankPurchasePromptRegistered then
        bankPurchasePromptRegistered = NSkin:RegisterSkinningElement(
            IDs.BankPurchasePrompt, {
                module = "Storage",
                appearanceWindowID = IDs.Scope,
                label = "Bank purchase prompt",
                kind = "WINDOW",
                window = frame,
                target = prompt,
                priority = 80,
                draggable = false,
                appearanceStyles = { "window" },
                appearanceTypeIDs = { "WINDOW" },
                highlightRegions = { prompt },
                pixelBorderTargets = { prompt },
                refreshAppearance = function()
                    return StorageSkin:ApplyBankPurchasePrompt(frame, panel)
                end,
                refreshLayout = function()
                    return StorageSkin:ApplyBankPurchasePrompt(frame, panel)
                end,
                isEditable = function()
                    return IsVisible(frame) and IsVisible(prompt)
                end,
            }) == true
    end

    local applied = bankPurchasePromptRegistered
    for index, definition in ipairs({
        { IDs.BankPurchasePromptTitle, "Bank purchase prompt title",
            prompt.Title },
        { IDs.BankPurchasePromptText, "Bank purchase prompt text",
            prompt.PromptText },
        { IDs.BankPurchasePromptTabCost, "Bank purchase tab cost",
            costFrame.TabCost },
    }) do
        local id, label, text = unpack(definition)
        if text then
            applied = NSkin:RegisterTextElement({
                id = id,
                module = "Storage",
                appearanceWindowID = IDs.Scope,
                label = label,
                window = frame,
                target = text,
                priority = 81 + index,
                highlightRegions = { text },
                isEditable = function()
                    return IsVisible(frame) and IsVisible(prompt)
                        and IsVisible(text)
                end,
            }) ~= nil or applied
        end
    end

    local moneyDisplay = costFrame.MoneyDisplay
    for index, definition in ipairs({
        { IDs.BankPurchasePromptGoldText, "Bank purchase cost gold",
            "Gold", "GOLD" },
        { IDs.BankPurchasePromptSilverText, "Bank purchase cost silver",
            "Silver" },
        { IDs.BankPurchasePromptCopperText, "Bank purchase cost copper",
            "Copper" },
    }) do
        local id, label, denomination, numberFormat = unpack(definition)
        local text = GetMoneyText(moneyDisplay, denomination)
        if text then
            applied = NSkin:RegisterTextElement({
                id = id,
                module = "Storage",
                appearanceWindowID = IDs.Scope,
                label = label,
                window = frame,
                target = text,
                priority = 84 + index,
                numberFormat = numberFormat,
                highlightRegions = { text },
                isEditable = function()
                    return IsVisible(frame) and IsVisible(prompt)
                        and IsVisible(text)
                end,
            }) ~= nil or applied
        end
    end

    local purchaseButton = costFrame.PurchaseButton
        or prompt.PurchaseButton
    if purchaseButton then
        applied = NSkin:RegisterTypedElement("BUTTON", {
            id = IDs.BankPurchasePromptButton,
            module = "Storage",
            appearanceWindowID = IDs.Scope,
            label = "Bank purchase button",
            window = frame,
            target = purchaseButton,
            priority = 88,
            highlightRegions = { purchaseButton },
            isEditable = function()
                return IsVisible(frame) and IsVisible(prompt)
                    and IsVisible(purchaseButton)
            end,
        }) ~= nil or applied
    end
    return applied
end

function StorageSkin:ApplyBankCurrency(frame, panel)
    local moneyFrame = panel and panel.MoneyFrame
    if not moneyFrame then return false end

    local backgrounds = GetDirectRegions(moneyFrame)
    AppendRegions(backgrounds, GetDirectRegions(moneyFrame.Border))
    SetDecorationsSuppressed(moneyFrame, "MoneyBackground",
        backgrounds, true)

    local moneyDisplay = moneyFrame.MoneyDisplay or moneyFrame
    local applied = false
    for index, definition in ipairs({
        { IDs.BankGoldText, "Bank gold", "Gold", "GOLD" },
        { IDs.BankSilverText, "Bank silver", "Silver" },
        { IDs.BankCopperText, "Bank copper", "Copper" },
    }) do
        local id, label, denomination, numberFormat = unpack(definition)
        local text = GetMoneyText(moneyDisplay, denomination)
            or _G["BankPanel" .. denomination .. "ButtonText"]
        if text then
            applied = NSkin:RegisterTextElement({
                id = id,
                module = "Storage",
                appearanceWindowID = IDs.Scope,
                label = label,
                window = frame,
                target = text,
                priority = 60 + index,
                numberFormat = numberFormat,
                highlightRegions = { text },
                isEditable = function()
                    return IsVisible(frame) and IsVisible(text)
                end,
            }) ~= nil or applied
        end
    end
    for index, definition in ipairs({
        { IDs.BankWithdrawButton, "Bank withdraw button",
            moneyFrame.WithdrawButton },
        { IDs.BankDepositButton, "Bank deposit button",
            moneyFrame.DepositButton },
    }) do
        local id, label, button = unpack(definition)
        if button then
            applied = NSkin:RegisterTypedElement("BUTTON", {
                id = id,
                module = "Storage",
                appearanceWindowID = IDs.Scope,
                label = label,
                window = frame,
                target = button,
                priority = 64 + index,
                highlightRegions = { button },
                isEditable = function()
                    return IsVisible(frame) and IsVisible(button)
                end,
            }) ~= nil or applied
        end
    end
    return applied
end

function StorageSkin:ApplyBankItems(frame, panel)
    if not frame or not panel then return false end
    if not registeredItemGroups[IDs.BankItems] then
        registeredItemGroups[IDs.BankItems] = NSkin:RegisterIconGroup({
            id = IDs.BankItems,
            module = "Storage",
            appearanceWindowID = IDs.Scope,
            label = "Bank storage items",
            window = frame,
            target = panel,
            priority = 70,
            draggable = false,
            children = function()
                return GetBankItemDescriptors(panel)
            end,
            highlightRegions = function()
                return GetBankItemButtons(panel, true)
            end,
            pixelBorderTargets = function()
                return GetBankItemButtons(panel, true)
            end,
            isEditable = function()
                return IsVisible(frame)
                    and #GetBankItemButtons(panel, true) > 0
            end,
        }) ~= nil
    else
        NSkin:RefreshIconGroup(IDs.BankItems)
    end
    return registeredItemGroups[IDs.BankItems]
end

function StorageSkin:ApplyBank()
    local frame = _G.BankFrame
    local panel = frame and (frame.BankPanel or _G.BankPanel)
    if not frame or not panel then return false end

    SetDecorationsSuppressed(frame, "BankBackground",
        CompactRegions(frame.Background), true)
    local panelDecorations = GetDirectRegions(panel.EdgeShadows)
    AppendRegions(panelDecorations, GetDirectRegions(panel.NineSlice))
    SetDecorationsSuppressed(panel, "BankPanelDecorations",
        panelDecorations, true)

    local applied = self:ApplyWindowChrome(frame, IDs.BankWindow,
        IDs.BankHeaderControls, "Bank window")
    applied = self:ApplyBankControls(frame, panel) or applied
    applied = self:ApplyBankBottomTabs(frame) or applied
    applied = self:ApplyBankSideTabs(frame, panel) or applied
    applied = self:ApplyBankPurchasePrompt(frame, panel) or applied
    applied = self:ApplyBankCurrency(frame, panel) or applied
    applied = self:ApplyBankItems(frame, panel) or applied
    return applied
end

function StorageSkin:HookBankLifecycle()
    if bankLifecycleHooked then return end
    local frame = _G.BankFrame
    local panel = frame and (frame.BankPanel or _G.BankPanel)
    if not frame or not panel then return end

    if frame.HookScript then
        frame:HookScript("OnShow", function()
            StorageSkin:ApplyBank()
        end)
    end
    local purchasePrompt = panel.PurchasePrompt
    if purchasePrompt and purchasePrompt.HookScript then
        purchasePrompt:HookScript("OnShow", function()
            StorageSkin:ApplyBankPurchasePrompt(frame, panel)
        end)
    end
    if _G.hooksecurefunc then
        for _, method in ipairs({ "SetTab", "RefreshTabVisibility" }) do
            if type(frame[method]) == "function" then
                pcall(_G.hooksecurefunc, frame, method, function()
                    StorageSkin:ApplyBankBottomTabs(frame)
                end)
            end
        end
        for _, method in ipairs({
            "GenerateItemSlotsForSelectedTab",
            "RefreshAllItemsForSelectedTab",
        }) do
            if type(panel[method]) == "function" then
                pcall(_G.hooksecurefunc, panel, method, function()
                    StorageSkin:ApplyBankItems(frame, panel)
                end)
            end
        end
        if type(panel.RefreshBankTabs) == "function" then
            pcall(_G.hooksecurefunc, panel, "RefreshBankTabs", function()
                StorageSkin:ApplyBankSideTabs(frame, panel)
            end)
        end
        local moneyFrame = panel.MoneyFrame
        if moneyFrame and type(moneyFrame.Refresh) == "function" then
            pcall(_G.hooksecurefunc, moneyFrame, "Refresh", function()
                StorageSkin:ApplyBankCurrency(frame, panel)
            end)
        end
    end
    bankLifecycleHooked = true
end

function StorageSkin:Apply()
    local combinedFrame = _G.ContainerFrameCombinedBags
    local individualFrames = GetIndividualContainerFrames()
    if not combinedFrame and #individualFrames == 0
        and not _G.BankFrame then return false end
    local applied = false
    if combinedFrame then
        applied = self:ApplyWindowChrome(combinedFrame, IDs.Window,
            IDs.HeaderControls, "Combined Bags window") or applied
        applied = self:ApplyControls(combinedFrame) or applied
        applied = self:ApplyCurrency(combinedFrame, IDs.GoldText,
            IDs.SilverText, "Combined Bags") or applied
        applied = self:ApplyTokenFrame() or applied
        applied = self:ApplyItemIcons(combinedFrame, IDs.CombinedItems,
            "Combined Bags items") or applied
    end
    for _, entry in ipairs(individualFrames) do
        local index, frame = entry.index, entry.frame
        local windowID, headerControlsID, itemsID, goldID, silverID =
            GetIndividualContainerFrameIDs(index)
        applied = self:ApplyWindowChrome(frame, windowID,
            headerControlsID, "ContainerFrame" .. index .. " window")
            or applied
        applied = self:ApplyItemIcons(frame, itemsID,
            "ContainerFrame" .. index .. " items") or applied
        applied = self:ApplyCurrency(frame, goldID, silverID,
            "ContainerFrame" .. index) or applied
    end
    applied = self:ApplyBank() or applied
    return applied
end

function StorageSkin:Initialize()
    local combinedFrame = _G.ContainerFrameCombinedBags
    local individualFrames = GetIndividualContainerFrames()
    if not combinedFrame and #individualFrames == 0
        and not _G.BankFrame then return false end
    self:HookContainerFrame(combinedFrame, IDs.CombinedItems,
        "Combined Bags items")
    self:HookContainerCurrency(combinedFrame, IDs.GoldText,
        IDs.SilverText, "Combined Bags")
    for _, entry in ipairs(individualFrames) do
        local _, _, itemsID, goldID, silverID =
            GetIndividualContainerFrameIDs(entry.index)
        self:HookContainerFrame(entry.frame, itemsID,
            "ContainerFrame" .. entry.index .. " items")
        self:HookContainerCurrency(entry.frame, goldID, silverID,
            "ContainerFrame" .. entry.index)
    end
    self:HookBankLifecycle()
    initialized = true
    return self:Apply()
end

function StorageSkin:InitializeTokens()
    self:ApplyTokenFrame()
    if initialized then self:Apply() end
    return true
end

function StorageSkin:RefreshAppearance()
    if initialized then self:Apply() end
end

NSkin:RegisterWindowSkin({
    module = "Storage",
    addon = "Blizzard_UIPanels_Game",
    apply = function() return StorageSkin:Initialize() end,
})

NSkin:RegisterWindowSkin({
    key = "Storage.Tokens",
    module = "Storage",
    addon = "Blizzard_TokenUI",
    apply = function() return StorageSkin:InitializeTokens() end,
})
