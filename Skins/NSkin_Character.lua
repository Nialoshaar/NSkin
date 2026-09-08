local _, NSkin = ...

local CharacterSkin = NSkin:NewModule("Character")

local IDs = {
    Scope = "Character",
    Window = "Character.Window",
    HeaderControls = "Character.HeaderControls",
    BottomTabs = "Character.BottomTabs",
    TitleScrollBar = "Character.Titles.ScrollBar",
    Equipment = {
        ScrollBar = "Character.EquipmentManager.ScrollBar",
        EquipButton = "Character.EquipmentManager.EquipButton",
        SaveButton = "Character.EquipmentManager.SaveButton",
        Popup = {
            Scope = "Character.EquipmentManager.IconSelectPopup",
            Window = "Character.EquipmentManager.IconSelectPopup.Window",
            HeaderControls =
                "Character.EquipmentManager.IconSelectPopup.HeaderControls",
            TextBox = "Character.EquipmentManager.IconSelectPopup.TextBox",
            Dropdown = "Character.EquipmentManager.IconSelectPopup.Dropdown",
            OkayButton =
                "Character.EquipmentManager.IconSelectPopup.OkayButton",
            CancelButton =
                "Character.EquipmentManager.IconSelectPopup.CancelButton",
            IconSelectionText =
                "Character.EquipmentManager.IconSelectPopup.IconSelectionText",
            SelectedIconHeader =
                "Character.EquipmentManager.IconSelectPopup.SelectedIconHeader",
            SelectedIconDescription =
                "Character.EquipmentManager.IconSelectPopup.SelectedIconDescription",
            EditBoxHeaderText =
                "Character.EquipmentManager.IconSelectPopup.EditBoxHeaderText",
            SelectedIcon =
                "Character.EquipmentManager.IconSelectPopup.SelectedIcon",
            IconPrefix = "Character.EquipmentManager.IconSelectPopup.Icon.",
            ScrollBar =
                "Character.EquipmentManager.IconSelectPopup.ScrollBar",
        },
    },
    ReputationDropdown = "Character.Reputation.FilterDropdown",
    ReputationScrollBar = "Character.Reputation.ScrollBar",
    ReputationSectionCards = "Character.Reputation.SectionCards",
    ReputationDetails = {
        Scope = "Character.ReputationDetails",
        Window = "Character.ReputationDetails.Window",
        HeaderControls = "Character.ReputationDetails.HeaderControls",
        DescriptionScrollBar =
            "Character.ReputationDetails.DescriptionScrollBar",
        AtWarCheckbox = "Character.ReputationDetails.AtWarCheckbox",
        InactiveCheckbox = "Character.ReputationDetails.InactiveCheckbox",
        WatchCheckbox = "Character.ReputationDetails.WatchCheckbox",
        ViewRenownButton = "Character.ReputationDetails.ViewRenownButton",
    },
    CurrencyDropdown = "Character.Currency.FilterDropdown",
    CurrencyScrollBar = "Character.Currency.ScrollBar",
    CurrencySectionCards = "Character.Currency.SectionCards",
    CurrencyOptions = {
        Scope = "Character.CurrencyOptions",
        Window = "Character.CurrencyOptions.Window",
        HeaderControls = "Character.CurrencyOptions.HeaderControls",
        UnusedCheckbox = "Character.CurrencyOptions.UnusedCheckbox",
        BackpackCheckbox = "Character.CurrencyOptions.BackpackCheckbox",
        TransferButton = "Character.CurrencyOptions.TransferButton",
    },
    CurrencyTransfer = {
        Scope = "Character.CurrencyTransfer",
        Window = "Character.CurrencyTransfer.Window",
        HeaderControls = "Character.CurrencyTransfer.HeaderControls",
        SourceDropdown = "Character.CurrencyTransfer.SourceDropdown",
        AmountInput = "Character.CurrencyTransfer.AmountInput",
        MaxButton = "Character.CurrencyTransfer.MaxButton",
        ConfirmButton = "Character.CurrencyTransfer.ConfirmButton",
        CancelButton = "Character.CurrencyTransfer.CancelButton",
    },
    CurrencyTransferLog = {
        Scope = "Character.CurrencyTransferLog",
        Window = "Character.CurrencyTransferLog.Window",
        HeaderControls = "Character.CurrencyTransferLog.HeaderControls",
        ScrollBar = "Character.CurrencyTransferLog.ScrollBar",
    },
    ItemSocketing = {
        Scope = "Character.ItemSocketing",
        Window = "Character.ItemSocketing.Window",
        HeaderControls = "Character.ItemSocketing.HeaderControls",
        ApplyButton = "Character.ItemSocketing.ApplyButton",
    },
}

local initialized = false
local showHooked = false
local toggleHooked = false
local equipmentPopupLifecycleHooked = false
local tabsRegistered = false
local applyPending = false
local reputationSectionCardsHooked = false
local reputationSectionCardsRegistered = false
local currencySectionCardsHooked = false
local currencySectionCardsRegistered = false
local hookedTabs = setmetatable({}, { __mode = "k" })
local hookedShowOwners = setmetatable({}, { __mode = "k" })
local concealedDetailArtwork = setmetatable({}, { __mode = "k" })
local concealedSocketingArtwork = setmetatable({}, { __mode = "k" })

NSkin:RegisterAppearanceScope(IDs.Scope, {
    label = "Character",
})
NSkin:RegisterAppearanceScope(IDs.Equipment.Popup.Scope, {
    label = "Equipment Manager Icon Select",
    parent = IDs.Scope,
})
NSkin:RegisterAppearanceScope(IDs.ReputationDetails.Scope, {
    label = "Reputation Details",
    parent = IDs.Scope,
})
NSkin:RegisterAppearanceScope(IDs.CurrencyOptions.Scope, {
    label = "Currency Options",
    parent = IDs.Scope,
})
NSkin:RegisterAppearanceScope(IDs.CurrencyTransfer.Scope, {
    label = "Currency Transfer",
    parent = IDs.Scope,
})
NSkin:RegisterAppearanceScope(IDs.CurrencyTransferLog.Scope, {
    label = "Currency Transfer Log",
    parent = IDs.Scope,
})
NSkin:RegisterAppearanceScope(IDs.ItemSocketing.Scope, {
    label = "Item Socketing",
    parent = IDs.Scope,
})

local function GetTabs()
    return {
        _G.CharacterFrameTab1,
        _G.CharacterFrameTab2,
        _G.CharacterFrameTab3,
    }
end

local function QueueApply()
    if applyPending then return end
    applyPending = true
    C_Timer.After(0, function()
        applyPending = false
        CharacterSkin:Apply()
    end)
end

local function HookTabRefresh(tab)
    if not tab or hookedTabs[tab] or not tab.HookScript then return end
    tab:HookScript("OnClick", QueueApply)
    hookedTabs[tab] = true
end

local function HookOwnerRefresh(owner)
    if not owner or hookedShowOwners[owner] or not owner.HookScript then
        return
    end
    owner:HookScript("OnShow", QueueApply)
    hookedShowOwners[owner] = true
end

local function GetCheckboxText(checkBox)
    if not checkBox then return nil end
    local name = checkBox.GetName and checkBox:GetName()
    return checkBox.Text or checkBox.text or (name and _G[name .. "Text"])
end

local function ConcealTexture(texture)
    if not texture then return end
    texture:SetAlpha(0)
    texture:Hide()
end

local CHARACTER_SECTION_ARTWORK = {
    "Background", "Left", "Middle", "Right",
    "HighlightLeft", "HighlightMiddle", "HighlightRight",
}

local function IsCharacterSectionCard(frame)
    return frame and type(frame.IsCollapsed) == "function"
        and frame.Right ~= nil
end

local function GetCharacterSectionCardArtwork(frame)
    local artwork = {}
    for i = 1, #CHARACTER_SECTION_ARTWORK do
        local region = frame[CHARACTER_SECTION_ARTWORK[i]]
        if region then artwork[#artwork + 1] = region end
    end
    return artwork
end

local function IsCharacterSectionCardExpanded(frame)
    local elementData = frame.GetElementData and frame:GetElementData()
        or frame.elementData
    if elementData then
        if elementData.isHeaderExpanded ~= nil
            or elementData.currencyListDepth ~= nil
        then
            return elementData.isHeaderExpanded == true
        end
        if elementData.isCollapsed ~= nil then
            return elementData.isCollapsed ~= true
        end
    end
    local ok, collapsed = pcall(frame.IsCollapsed, frame)
    if not ok or collapsed == nil then return nil end
    if type(collapsed) == "number" then return collapsed == 0 end
    if type(collapsed) == "boolean" then return not collapsed end
    return nil
end

local function GetVisibleCharacterSectionCards(scrollBox)
    local cards = {}
    if scrollBox and scrollBox.ForEachFrame then
        scrollBox:ForEachFrame(function(frame)
            if IsCharacterSectionCard(frame) and frame:IsShown() then
                cards[#cards + 1] = frame
            end
        end)
    end
    return cards
end

local function SkinCharacterSectionCards(scrollBox, elementID, registered)
    if not scrollBox or not scrollBox.ForEachFrame then return false end
    local style = NSkin:GetAppearanceStyle(
        "sectionCard", IDs.Scope, elementID)
    local border = NSkin:GetAppearanceBorderColor(
        "sectionCard", style, IDs.Scope, elementID)
    local applied
    scrollBox:ForEachFrame(function(frame)
        if IsCharacterSectionCard(frame) then
            NSkin:SkinSectionCard(frame, {
                style = style,
                border = border,
                collapsible = true,
                getExpanded = IsCharacterSectionCardExpanded,
                textRegion = frame.Name,
                artworkRegions = GetCharacterSectionCardArtwork(frame),
            })
            applied = true
        end
    end)
    if registered then NSkin:NotifySkinningElementBoundsChanged(elementID) end
    return applied == true
end

local function ApplyAuxiliaryWindowChrome(frame, scopeID, windowID,
    headerControlsID, label, title)
    if not frame then return false end

    NSkin:SkinStandardWindowChrome({
        frame = frame,
        appearanceWindowID = scopeID,
        elementID = windowID,
        headerControlsID = headerControlsID,
        title = title,
    })
    NSkin:RegisterSkinningElement(windowID, {
        label = label,
        kind = "WINDOW",
        module = "Character",
        appearanceWindowID = scopeID,
        window = frame,
        target = frame,
        priority = 0,
        draggable = false,
    })
    HookOwnerRefresh(frame)
    return true
end

function CharacterSkin:ApplyWindowChrome(frame)
    if not frame then return false end

    NSkin:SkinStandardWindowChrome({
        frame = frame,
        appearanceWindowID = IDs.Scope,
        elementID = IDs.Window,
        headerControlsID = IDs.HeaderControls,
        title = _G.CharacterFrameTitleText,
    })
    NSkin:RegisterSkinningElement(IDs.Window, {
        label = "Character window",
        kind = "WINDOW",
        module = "Character",
        appearanceWindowID = IDs.Scope,
        window = frame,
        target = frame,
        priority = 0,
        draggable = false,
    })
    return true
end

function CharacterSkin:ApplyTabs(frame)
    if not frame then return false end
    local tabs = GetTabs()
    for i = 1, #tabs do
        if not tabs[i] then return false end
    end

    local style = NSkin:GetAppearanceStyle(
        "tab", IDs.Scope, IDs.BottomTabs)
    local border = NSkin:GetAppearanceBorderColor(
        "tab", style, IDs.Scope, IDs.BottomTabs)
    local selected = _G.PanelTemplates_GetSelectedTab
        and _G.PanelTemplates_GetSelectedTab(frame)
    for i = 1, #tabs do
        NSkin:SkinTab(tabs[i], i == selected, style, border)
        HookTabRefresh(tabs[i])
    end

    if not tabsRegistered then
        tabsRegistered = NSkin:RegisterTabGroup(IDs.BottomTabs, {
            label = "Character bottom tabs",
            kind = "TAB_GROUP",
            module = "Character",
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

function CharacterSkin:ApplyPaperDollControls(frame)
    local paperDoll = _G.PaperDollFrame
    if not frame or not paperDoll then return false end

    local titles = paperDoll.TitleManagerPane
    local equipment = paperDoll.EquipmentManagerPane
    local titleScrollBar = titles and titles.ScrollBar
    local equipmentScrollBar = equipment and equipment.ScrollBar
    local equipButton = equipment and equipment.EquipSet
    local saveButton = equipment and equipment.SaveSet
    local applied = NSkin:RegisterScrollBar({
        id = IDs.TitleScrollBar, module = "Character",
        appearanceWindowID = IDs.Scope,
        label = "Character titles scroll bar", window = frame,
        target = titleScrollBar, priority = 80,
        highlightRegions = { titleScrollBar },
        isEditable = function()
            return frame:IsVisible() and titles:IsVisible()
                and titleScrollBar:IsVisible()
        end,
    }) ~= nil
    applied = NSkin:RegisterScrollBar({
        id = IDs.Equipment.ScrollBar, module = "Character",
        appearanceWindowID = IDs.Scope,
        label = "Equipment manager scroll bar", window = frame,
        target = equipmentScrollBar, priority = 81,
        highlightRegions = { equipmentScrollBar },
        isEditable = function()
            return frame:IsVisible() and equipment:IsVisible()
                and equipmentScrollBar:IsVisible()
        end,
    }) ~= nil or applied
    applied = NSkin:RegisterActionButton({
        id = IDs.Equipment.EquipButton, module = "Character",
        appearanceWindowID = IDs.Scope,
        label = "Equipment manager equip button", window = frame,
        target = equipButton, priority = 82,
        highlightRegions = { equipButton },
        isEditable = function()
            return frame:IsVisible() and equipment:IsVisible()
                and equipButton:IsVisible()
        end,
    }) ~= nil or applied
    applied = NSkin:RegisterActionButton({
        id = IDs.Equipment.SaveButton, module = "Character",
        appearanceWindowID = IDs.Scope,
        label = "Equipment manager save button", window = frame,
        target = saveButton, priority = 83,
        highlightRegions = { saveButton },
        isEditable = function()
            return frame:IsVisible() and equipment:IsVisible()
                and saveButton:IsVisible()
        end,
    }) ~= nil or applied
    HookOwnerRefresh(titles)
    HookOwnerRefresh(equipment)
    return applied
end

function CharacterSkin:ApplyEquipmentManagerPopup()
    local popup = _G.GearManagerPopupFrame
    if not popup then return false end
    local popupIDs = IDs.Equipment.Popup
    return NSkin:RegisterIconSelectPopup({
        root = popup,
        module = "Character",
        appearanceWindowID = popupIDs.Scope,
        windowLabel = "Equipment manager icon select popup",
        ids = {
            window = popupIDs.Window,
            headerControls = popupIDs.HeaderControls,
            textBox = popupIDs.TextBox,
            dropdown = popupIDs.Dropdown,
            okayButton = popupIDs.OkayButton,
            cancelButton = popupIDs.CancelButton,
            iconSelectionText = popupIDs.IconSelectionText,
            selectedIconHeader = popupIDs.SelectedIconHeader,
            selectedIconDescription = popupIDs.SelectedIconDescription,
            editBoxHeaderText = popupIDs.EditBoxHeaderText,
            selectedIcon = popupIDs.SelectedIcon,
            iconPrefix = popupIDs.IconPrefix,
            scrollBar = popupIDs.ScrollBar,
        },
    })
end

function CharacterSkin:ApplyReputationDropdown(frame)
    local reputation = _G.ReputationFrame
    local scrollBox = reputation and reputation.ScrollBox
    local dropdown = reputation and reputation.filterDropdown
    local applied = NSkin:RegisterDropdown({
        id = IDs.ReputationDropdown, module = "Character",
        appearanceWindowID = IDs.Scope,
        label = "Reputation filter dropdown", window = frame,
        target = dropdown, menus = { "MENU_REPUTATION_FRAME_FILTER" },
        priority = 84,
        highlightRegions = { dropdown },
        isEditable = function()
            return frame:IsVisible() and reputation:IsVisible()
                and dropdown:IsVisible()
        end,
    })
    applied = NSkin:RegisterScrollBar({
        id = IDs.ReputationScrollBar, module = "Character",
        appearanceWindowID = IDs.Scope,
        label = "Reputation scroll bar", window = frame,
        target = reputation and reputation.ScrollBar, priority = 85,
        highlightRegions = { reputation and reputation.ScrollBar },
        isEditable = function()
            return frame:IsVisible() and reputation:IsVisible()
                and reputation.ScrollBar:IsVisible()
        end,
    }) or applied
    applied = SkinCharacterSectionCards(scrollBox,
        IDs.ReputationSectionCards, reputationSectionCardsRegistered) or applied
    if scrollBox and not reputationSectionCardsRegistered then
        reputationSectionCardsRegistered = NSkin:RegisterSkinningElement(
            IDs.ReputationSectionCards, {
                module = "Character",
                appearanceWindowID = IDs.Scope,
                label = "Reputation section cards",
                kind = "SECTION_CARD",
                window = frame,
                target = scrollBox,
                priority = 86,
                draggable = false,
                highlightRegions = function()
                    return GetVisibleCharacterSectionCards(scrollBox)
                end,
                editorOptions = {
                    { id = "shared.sectionCardAppearance",
                        label = "Section cards", category = "CUSTOMIZE" },
                },
                isEditable = function()
                    return frame:IsVisible() and reputation:IsVisible()
                        and #GetVisibleCharacterSectionCards(scrollBox) > 0
                end,
            }) == true
    end
    if scrollBox and not reputationSectionCardsHooked
        and _G.hooksecurefunc and type(scrollBox.Update) == "function"
    then
        _G.hooksecurefunc(scrollBox, "Update", function(updatedScrollBox)
            SkinCharacterSectionCards(updatedScrollBox,
                IDs.ReputationSectionCards,
                reputationSectionCardsRegistered)
        end)
        reputationSectionCardsHooked = true
    end
    if applied then HookOwnerRefresh(reputation) end
    return applied ~= nil
end

function CharacterSkin:ApplyReputationDetails()
    local reputation = _G.ReputationFrame
    local details = reputation and reputation.ReputationDetailFrame
    if not details then return false end

    -- DialogBorderTemplate and the anonymous parchment/divider textures are
    -- outside the standard window artwork keys.
    if not concealedDetailArtwork[details] then
        NSkin:HideTextureRegions(details)
        concealedDetailArtwork[details] = true
    end
    NSkin:ConcealWindowArtwork(details.Border)
    local applied = ApplyAuxiliaryWindowChrome(
        details, IDs.ReputationDetails.Scope, IDs.ReputationDetails.Window,
        IDs.ReputationDetails.HeaderControls, "Reputation Details window",
        details.Title)

    local scrollBar = details.ScrollingDescriptionScrollBar
    local atWar = details.AtWarCheckbox
    local inactive = details.MakeInactiveCheckbox
    local watch = details.WatchFactionCheckbox
    local viewRenown = details.ViewRenownButton
    applied = NSkin:RegisterScrollBar({
        id = IDs.ReputationDetails.DescriptionScrollBar,
        module = "Character",
        appearanceWindowID = IDs.ReputationDetails.Scope,
        label = "Reputation description scroll bar", window = details,
        target = scrollBar, priority = 70,
        highlightRegions = { scrollBar },
        isEditable = function()
            return details:IsVisible() and scrollBar:IsVisible()
        end,
    }) ~= nil or applied
    applied = NSkin:RegisterCheckbox({
        id = IDs.ReputationDetails.AtWarCheckbox, module = "Character",
        appearanceWindowID = IDs.ReputationDetails.Scope,
        label = "At War checkbox", window = details,
        target = atWar, text = atWar and atWar.Label, priority = 71,
        highlightRegions = { atWar },
        isEditable = function()
            return details:IsVisible() and atWar:IsVisible()
        end,
    }) ~= nil or applied
    applied = NSkin:RegisterCheckbox({
        id = IDs.ReputationDetails.InactiveCheckbox, module = "Character",
        appearanceWindowID = IDs.ReputationDetails.Scope,
        label = "Move to inactive checkbox", window = details,
        target = inactive, text = inactive and inactive.Label, priority = 72,
        highlightRegions = { inactive },
        isEditable = function()
            return details:IsVisible() and inactive:IsVisible()
        end,
    }) ~= nil or applied
    applied = NSkin:RegisterCheckbox({
        id = IDs.ReputationDetails.WatchCheckbox, module = "Character",
        appearanceWindowID = IDs.ReputationDetails.Scope,
        label = "Experience bar checkbox", window = details,
        target = watch, text = watch and watch.Label, priority = 73,
        highlightRegions = { watch },
        isEditable = function()
            return details:IsVisible() and watch:IsVisible()
        end,
    }) ~= nil or applied
    applied = NSkin:RegisterActionButton({
        id = IDs.ReputationDetails.ViewRenownButton, module = "Character",
        appearanceWindowID = IDs.ReputationDetails.Scope,
        label = "View Renown button", window = details,
        target = viewRenown, priority = 74,
        highlightRegions = { viewRenown },
        isEditable = function()
            return details:IsVisible() and viewRenown:IsVisible()
        end,
    }) ~= nil or applied
    return applied
end

function CharacterSkin:ApplyCurrencyDropdown(frame)
    local currency = _G.TokenFrame
    local scrollBox = currency and currency.ScrollBox
    local dropdown = currency and currency.filterDropdown
    local applied = NSkin:RegisterDropdown({
        id = IDs.CurrencyDropdown, module = "Character",
        appearanceWindowID = IDs.Scope,
        label = "Currency filter dropdown", window = frame,
        target = dropdown, menus = { "MENU_CURRENCY_FRAME_FILTER" },
        priority = 85,
        highlightRegions = { dropdown },
        isEditable = function()
            return frame:IsVisible() and currency:IsVisible()
                and dropdown:IsVisible()
        end,
    })
    applied = NSkin:RegisterScrollBar({
        id = IDs.CurrencyScrollBar, module = "Character",
        appearanceWindowID = IDs.Scope,
        label = "Currency scroll bar", window = frame,
        target = currency and currency.ScrollBar, priority = 86,
        highlightRegions = { currency and currency.ScrollBar },
        isEditable = function()
            return frame:IsVisible() and currency:IsVisible()
                and currency.ScrollBar:IsVisible()
        end,
    }) or applied
    applied = SkinCharacterSectionCards(scrollBox,
        IDs.CurrencySectionCards, currencySectionCardsRegistered) or applied
    if scrollBox and not currencySectionCardsRegistered then
        currencySectionCardsRegistered = NSkin:RegisterSkinningElement(
            IDs.CurrencySectionCards, {
                module = "Character",
                appearanceWindowID = IDs.Scope,
                label = "Currency section cards",
                kind = "SECTION_CARD",
                window = frame,
                target = scrollBox,
                priority = 87,
                draggable = false,
                highlightRegions = function()
                    return GetVisibleCharacterSectionCards(scrollBox)
                end,
                editorOptions = {
                    { id = "shared.sectionCardAppearance",
                        label = "Section cards", category = "CUSTOMIZE" },
                },
                isEditable = function()
                    return frame:IsVisible() and currency:IsVisible()
                        and #GetVisibleCharacterSectionCards(scrollBox) > 0
                end,
            }) == true
    end
    if scrollBox and not currencySectionCardsHooked
        and _G.hooksecurefunc and type(scrollBox.Update) == "function"
    then
        _G.hooksecurefunc(scrollBox, "Update", function(updatedScrollBox)
            SkinCharacterSectionCards(updatedScrollBox,
                IDs.CurrencySectionCards, currencySectionCardsRegistered)
        end)
        currencySectionCardsHooked = true
    end
    if applied then HookOwnerRefresh(currency) end
    return applied ~= nil
end

function CharacterSkin:ApplyCurrencyOptions()
    local popup = _G.TokenFramePopup
    if not popup then return false end

    -- SecureDialogBorderTemplate is not part of the standard window chrome,
    -- but its artwork is. Preserve the frame while suppressing that artwork.
    NSkin:ConcealWindowArtwork(popup.Border)
    local applied = ApplyAuxiliaryWindowChrome(
        popup, IDs.CurrencyOptions.Scope, IDs.CurrencyOptions.Window,
        IDs.CurrencyOptions.HeaderControls, "Currency Options window",
        popup.Title)

    local unused = popup.InactiveCheckbox
    local backpack = popup.BackpackCheckbox
    local transfer = popup.CurrencyTransferToggleButton
    applied = NSkin:RegisterCheckbox({
        id = IDs.CurrencyOptions.UnusedCheckbox, module = "Character",
        appearanceWindowID = IDs.CurrencyOptions.Scope,
        label = "Show unused currencies", window = popup,
        target = unused, text = GetCheckboxText(unused), priority = 70,
        highlightRegions = { unused },
        isEditable = function()
            return popup:IsVisible() and unused:IsVisible()
        end,
    }) ~= nil or applied
    applied = NSkin:RegisterCheckbox({
        id = IDs.CurrencyOptions.BackpackCheckbox, module = "Character",
        appearanceWindowID = IDs.CurrencyOptions.Scope,
        label = "Show currency on backpack", window = popup,
        target = backpack, text = GetCheckboxText(backpack), priority = 71,
        highlightRegions = { backpack },
        isEditable = function()
            return popup:IsVisible() and backpack:IsVisible()
        end,
    }) ~= nil or applied
    applied = NSkin:RegisterActionButton({
        id = IDs.CurrencyOptions.TransferButton, module = "Character",
        appearanceWindowID = IDs.CurrencyOptions.Scope,
        label = "Transfer currency button", window = popup,
        target = transfer, priority = 72,
        highlightRegions = { transfer },
        isEditable = function()
            return popup:IsVisible() and transfer:IsVisible()
        end,
    }) ~= nil or applied
    return applied
end

function CharacterSkin:ApplyCurrencyTransfer()
    local transfer = _G.CurrencyTransferMenu
    local content = transfer and transfer.Content
    if not transfer or not content then return false end

    ConcealTexture(transfer.Background)
    NSkin:ConcealWindowArtwork(transfer.Inset)
    local applied = ApplyAuxiliaryWindowChrome(
        transfer, IDs.CurrencyTransfer.Scope, IDs.CurrencyTransfer.Window,
        IDs.CurrencyTransfer.HeaderControls, "Currency Transfer window")

    local sourceSelector = content.SourceSelector
    local sourceDropdown = sourceSelector and sourceSelector.Dropdown
    local amountSelector = content.AmountSelector
    local amountInput = amountSelector and amountSelector.InputBox
    local maxButton = amountSelector and amountSelector.MaxQuantityButton
    local confirmButton = content.ConfirmButton
    local cancelButton = content.CancelButton
    applied = NSkin:RegisterDropdown({
        id = IDs.CurrencyTransfer.SourceDropdown, module = "Character",
        appearanceWindowID = IDs.CurrencyTransfer.Scope,
        label = "Currency source dropdown", window = transfer,
        target = sourceDropdown, menus = { "MENU_CURRENCY_TRANSFER" },
        priority = 70, highlightRegions = { sourceDropdown },
        isEditable = function()
            return transfer:IsVisible() and sourceDropdown:IsVisible()
        end,
    }) ~= nil or applied
    applied = NSkin:RegisterSearchBox({
        id = IDs.CurrencyTransfer.AmountInput, module = "Character",
        appearanceWindowID = IDs.CurrencyTransfer.Scope,
        label = "Currency transfer amount", window = transfer,
        target = amountInput, priority = 71,
        highlightRegions = { amountInput },
        isEditable = function()
            return transfer:IsVisible() and amountInput:IsVisible()
        end,
    }) ~= nil or applied
    applied = NSkin:RegisterActionButton({
        id = IDs.CurrencyTransfer.MaxButton, module = "Character",
        appearanceWindowID = IDs.CurrencyTransfer.Scope,
        label = "Maximum currency button", window = transfer,
        target = maxButton, priority = 72,
        highlightRegions = { maxButton },
        isEditable = function()
            return transfer:IsVisible() and maxButton:IsVisible()
        end,
    }) ~= nil or applied
    applied = NSkin:RegisterActionButton({
        id = IDs.CurrencyTransfer.ConfirmButton, module = "Character",
        appearanceWindowID = IDs.CurrencyTransfer.Scope,
        label = "Confirm currency transfer", window = transfer,
        target = confirmButton, priority = 73,
        highlightRegions = { confirmButton },
        isEditable = function()
            return transfer:IsVisible() and confirmButton:IsVisible()
        end,
    }) ~= nil or applied
    applied = NSkin:RegisterActionButton({
        id = IDs.CurrencyTransfer.CancelButton, module = "Character",
        appearanceWindowID = IDs.CurrencyTransfer.Scope,
        label = "Cancel currency transfer", window = transfer,
        target = cancelButton, priority = 74,
        highlightRegions = { cancelButton },
        isEditable = function()
            return transfer:IsVisible() and cancelButton:IsVisible()
        end,
    }) ~= nil or applied
    return applied
end

function CharacterSkin:ApplyCurrencyTransferLog()
    local log = _G.CurrencyTransferLog
    if not log then return false end

    ConcealTexture(log.Background)
    NSkin:ConcealWindowArtwork(log.Inset)
    local applied = ApplyAuxiliaryWindowChrome(
        log, IDs.CurrencyTransferLog.Scope, IDs.CurrencyTransferLog.Window,
        IDs.CurrencyTransferLog.HeaderControls, "Currency Transfer Log window")
    local scrollBar = log.ScrollBar
    applied = NSkin:RegisterScrollBar({
        id = IDs.CurrencyTransferLog.ScrollBar, module = "Character",
        appearanceWindowID = IDs.CurrencyTransferLog.Scope,
        label = "Currency transfer log scroll bar", window = log,
        target = scrollBar, priority = 70,
        highlightRegions = { scrollBar },
        isEditable = function()
            return log:IsVisible() and scrollBar:IsVisible()
        end,
    }) ~= nil or applied
    return applied
end

function CharacterSkin:ApplyCurrencyWindows()
    local applied = self:ApplyCurrencyOptions()
    applied = self:ApplyCurrencyTransfer() or applied
    applied = self:ApplyCurrencyTransferLog() or applied
    return applied
end

function CharacterSkin:ApplyItemSocketing()
    local socketing = _G.ItemSocketingFrame
    if not socketing then return false end

    if not concealedSocketingArtwork[socketing] then
        NSkin:HideTextureRegions(socketing)
        concealedSocketingArtwork[socketing] = true
    end
    NSkin:ConcealWindowArtwork(socketing.Inset)
    local applied = ApplyAuxiliaryWindowChrome(
        socketing, IDs.ItemSocketing.Scope, IDs.ItemSocketing.Window,
        IDs.ItemSocketing.HeaderControls, "Item Socketing window")

    local container = socketing.SocketingContainer
    local applyButton = container and container.ApplySocketsButton
    applied = NSkin:RegisterActionButton({
        id = IDs.ItemSocketing.ApplyButton,
        module = "Character",
        appearanceWindowID = IDs.ItemSocketing.Scope,
        label = "Apply sockets button",
        window = socketing,
        target = applyButton,
        priority = 70,
        highlightRegions = { applyButton },
        isEditable = function()
            return socketing:IsVisible() and applyButton:IsVisible()
        end,
    }) ~= nil or applied
    HookOwnerRefresh(container)
    return applied
end

function CharacterSkin:Apply()
    local frame = _G.CharacterFrame
    if not frame then return false end
    self:ApplyWindowChrome(frame)
    self:ApplyTabs(frame)
    self:ApplyPaperDollControls(frame)
    self:ApplyEquipmentManagerPopup()
    self:ApplyReputationDropdown(frame)
    self:ApplyReputationDetails()
    self:ApplyCurrencyDropdown(frame)
    self:ApplyCurrencyWindows()
    self:ApplyItemSocketing()
    return true
end

function CharacterSkin:Initialize()
    local frame = _G.CharacterFrame
    if not frame then return false end

    if not showHooked and frame.HookScript then
        frame:HookScript("OnShow", QueueApply)
        showHooked = true
    end
    if not toggleHooked and _G.hooksecurefunc and _G.ToggleCharacter then
        _G.hooksecurefunc("ToggleCharacter", QueueApply)
        toggleHooked = true
    end
    local popup = _G.GearManagerPopupFrame
    if popup and not equipmentPopupLifecycleHooked and popup.HookScript then
        popup:HookScript("OnShow", function()
            CharacterSkin:ApplyEquipmentManagerPopup()
        end)
        equipmentPopupLifecycleHooked = true
    end

    initialized = true
    return self:Apply()
end

function CharacterSkin:RefreshAppearance()
    if initialized then self:Apply() end
end

function CharacterSkin:InitializeCurrency()
    local frame = _G.CharacterFrame
    if not frame or not _G.TokenFrame then return false end
    HookOwnerRefresh(_G.TokenFrame)
    return self:Apply()
end

function CharacterSkin:InitializeItemSocketing()
    return self:ApplyItemSocketing()
end

NSkin:RegisterWindowSkin({
    module = "Character",
    addon = "Blizzard_UIPanels_Game",
    apply = function() return CharacterSkin:Initialize() end,
})

NSkin:RegisterWindowSkin({
    key = "Character.Currency",
    module = "Character",
    addon = "Blizzard_TokenUI",
    apply = function() return CharacterSkin:InitializeCurrency() end,
})

NSkin:RegisterWindowSkin({
    key = "Character.ItemSocketing",
    module = "Character",
    addon = "Blizzard_ItemSocketingUI",
    apply = function() return CharacterSkin:InitializeItemSocketing() end,
})
