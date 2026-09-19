local _, NSkin = ...

local CharacterSkin = NSkin:NewModule("Character")

local IDs = {
    Scope = "Character",
    Window = "Character.Window",
    HeaderControls = "Character.HeaderControls",
    BottomTabs = "Character.BottomTabs",
    PaperDoll = {
        LevelText = "Character.PaperDoll.LevelText",
        EquipmentSlotPrefix = "Character.PaperDoll.Equipment.",
        EquipmentGroups = {
            Left = "Character.PaperDoll.Equipment.Left",
            Right = "Character.PaperDoll.Equipment.Right",
            Bottom = "Character.PaperDoll.Equipment.Bottom",
        },
        SideTabs = "Character.PaperDoll.SideTabs",
        CameraControls = "Character.PaperDoll.CameraControls",
        Stats = {
            ItemLevelHeader = "Character.Stats.ItemLevelHeader",
            ItemLevelValue = "Character.Stats.ItemLevelValue",
            AttributesHeader = "Character.Stats.AttributesHeader",
            EnhancementsHeader = "Character.Stats.EnhancementsHeader",
            Rows = "Character.Stats.Rows",
        },
    },
    Titles = {
        Rows = "Character.Titles.Rows",
        ScrollBar = "Character.Titles.ScrollBar",
    },
    Equipment = {
        Rows = "Character.EquipmentManager.Rows",
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
    ReputationSubHeaderRows = "Character.Reputation.SubHeaderRows",
    ReputationRows = "Character.Reputation.Rows",
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
    CurrencyTransferLogButton = "Character.Currency.TransferLogButton",
    CurrencyScrollBar = "Character.Currency.ScrollBar",
    CurrencySectionCards = "Character.Currency.SectionCards",
    CurrencySubHeaderRows = "Character.Currency.SubHeaderRows",
    CurrencyRows = "Character.Currency.Rows",
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
        SourceRow = "Character.CurrencyTransfer.SourceRow",
        AmountRow = "Character.CurrencyTransfer.AmountRow",
        SourceBalanceRow = "Character.CurrencyTransfer.SourceBalanceRow",
        PlayerBalanceRow = "Character.CurrencyTransfer.PlayerBalanceRow",
        ConfirmButton = "Character.CurrencyTransfer.ConfirmButton",
        CancelButton = "Character.CurrencyTransfer.CancelButton",
    },
    CurrencyTransferLog = {
        Scope = "Character.CurrencyTransferLog",
        Window = "Character.CurrencyTransferLog.Window",
        HeaderControls = "Character.CurrencyTransferLog.HeaderControls",
        EmptyMessage = "Character.CurrencyTransferLog.EmptyMessage",
        Rows = "Character.CurrencyTransferLog.Rows",
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
local reputationSubHeaderRowsRegistered = false
local reputationRowsRegistered = false
local currencySectionCardsHooked = false
local currencySectionCardsRegistered = false
local currencySubHeaderRowsRegistered = false
local currencyRowsRegistered = false
local currencyTransferLogRowsRegistered = false
local hookedTabs = setmetatable({}, { __mode = "k" })
local hookedShowOwners = setmetatable({}, { __mode = "k" })
local concealedDetailArtwork = setmetatable({}, { __mode = "k" })
local concealedSocketingArtwork = setmetatable({}, { __mode = "k" })
local hookedScrollBoxes = setmetatable({}, { __mode = "k" })
local paperDollStatsHooked = false

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


local PAPER_DOLL_SLOTS = {
    { name = "CharacterHeadSlot", key = "Head", label = "Head", group = "Left" },
    { name = "CharacterNeckSlot", key = "Neck", label = "Neck", group = "Left" },
    { name = "CharacterShoulderSlot", key = "Shoulder", label = "Shoulder", group = "Left" },
    { name = "CharacterBackSlot", key = "Back", label = "Back", group = "Left" },
    { name = "CharacterChestSlot", key = "Chest", label = "Chest", group = "Left" },
    { name = "CharacterShirtSlot", key = "Shirt", label = "Shirt", group = "Left" },
    { name = "CharacterTabardSlot", key = "Tabard", label = "Tabard", group = "Left" },
    { name = "CharacterWristSlot", key = "Wrist", label = "Wrist", group = "Left" },
    { name = "CharacterHandsSlot", key = "Hands", label = "Hands", group = "Right" },
    { name = "CharacterWaistSlot", key = "Waist", label = "Waist", group = "Right" },
    { name = "CharacterLegsSlot", key = "Legs", label = "Legs", group = "Right" },
    { name = "CharacterFeetSlot", key = "Feet", label = "Feet", group = "Right" },
    { name = "CharacterFinger0Slot", key = "Finger1", label = "Finger 1", group = "Right" },
    { name = "CharacterFinger1Slot", key = "Finger2", label = "Finger 2", group = "Right" },
    { name = "CharacterTrinket0Slot", key = "Trinket1", label = "Trinket 1", group = "Right" },
    { name = "CharacterTrinket1Slot", key = "Trinket2", label = "Trinket 2", group = "Right" },
    { name = "CharacterMainHandSlot", key = "MainHand", label = "Main Hand", group = "Bottom" },
    { name = "CharacterSecondaryHandSlot", key = "OffHand", label = "Off Hand", group = "Bottom" },
}

local PAPER_DOLL_GROUP_LABELS = {
    Left = "Left equipment",
    Right = "Right equipment",
    Bottom = "Bottom equipment",
}

local PAPER_DOLL_GROUP_APPEARANCE_SOURCE = {
    Left = "Head",
    Right = "Hands",
    Bottom = "MainHand",
}

local PAPER_DOLL_INNER_BORDER_NAMES = {
    "PaperDollInnerBorderTopLeft",
    "PaperDollInnerBorderTopRight",
    "PaperDollInnerBorderBottomLeft",
    "PaperDollInnerBorderBottomRight",
    "PaperDollInnerBorderLeft",
    "PaperDollInnerBorderRight",
    "PaperDollInnerBorderTop",
    "PaperDollInnerBorderBottom",
    "PaperDollInnerBorderBottom2",
}

local function GetPaperDollSlots(visibleOnly)
    local slots = {}
    for _, descriptor in ipairs(PAPER_DOLL_SLOTS) do
        local slot = _G[descriptor.name]
        if slot and (not visibleOnly or slot:IsVisible()) then
            slots[#slots + 1] = {
                frame = slot,
                key = descriptor.key,
                label = descriptor.label,
                group = descriptor.group,
            }
        end
    end
    return slots
end

local function GetPaperDollSlotTexture(slot)
    if not slot then return nil end
    local name = slot.GetName and slot:GetName()
    return slot.icon or slot.Icon
        or (name and _G[name .. "IconTexture"])
end

local function GetPaperDollSlotQuality(slot)
    if not slot or type(_G.GetInventoryItemQuality) ~= "function"
        or type(slot.GetID) ~= "function"
    then return nil end
    return _G.GetInventoryItemQuality("player", slot:GetID())
end

local function GetPaperDollSlotDecorations(slot, icon)
    local decorations = {}
    local seen = {}

    local function Add(region)
        if region and region ~= icon and not seen[region] then
            decorations[#decorations + 1] = region
            seen[region] = true
        end
    end

    local name = slot and slot.GetName and slot:GetName()
    Add(slot and slot.IconBorder)
    Add(slot and slot.GetNormalTexture and slot:GetNormalTexture())
    Add(name and _G[name .. "NormalTexture"])
    Add(name and _G[name .. "Frame"])

    -- The ornate left/right/bottom slot shells are direct BACKGROUND textures.
    -- Preserve the item icon and functional overlay textures.
    if slot and slot.GetRegions then
        for _, region in ipairs({ slot:GetRegions() }) do
            if region and region.GetObjectType
                and region:GetObjectType() == "Texture"
                and region ~= icon
            then
                local layer = region.GetDrawLayer and region:GetDrawLayer()
                if layer == "BACKGROUND" then
                    Add(region)
                end
            end
        end
    end

    return decorations
end

local function HookScrollBoxRefresh(scrollBox, callback)
    if not scrollBox or hookedScrollBoxes[scrollBox]
        or not _G.hooksecurefunc or type(scrollBox.Update) ~= "function"
    then
        return
    end
    _G.hooksecurefunc(scrollBox, "Update", callback)
    hookedScrollBoxes[scrollBox] = true
end

local function GetVisibleScrollBoxRows(scrollBox, predicate)
    local rows = {}
    if not scrollBox then return rows end
    NSkin:ForEachScrollBoxFrame(scrollBox, function(row)
        if row and row:IsShown() and (not predicate or predicate(row)) then
            rows[#rows + 1] = row
        end
    end)
    return rows
end

local function GetDirectStatRows(pane, visibleOnly)
    local rows = {}
    if not pane or not pane.GetChildren then return rows end
    for _, child in ipairs({ pane:GetChildren() }) do
        if child and child.Label and child.Value and child.Background
            and (not visibleOnly or child:IsShown())
        then
            rows[#rows + 1] = child
        end
    end
    return rows
end

local function IsTitleRow(row)
    return row and row.text and row.BgTop and row.BgBottom and row.BgMiddle
end

local function IsEquipmentRow(row)
    return row and row.icon and row.text and row.BgTop and row.BgBottom
        and row.BgMiddle and row.EditButton and row.DeleteButton
end

local function IsRowHovered(row)
    return row and row.IsMouseOver and row:IsMouseOver() or false
end

local function GetReputationElementData(row)
    if not row then return nil end
    if type(row.GetElementData) == "function" then
        local ok, data = pcall(row.GetElementData, row)
        if ok and data then return data end
    end
    return row.elementData
end

local function IsReputationSubHeaderRow(row)
    local data = GetReputationElementData(row)
    return data and data.isHeader == true and data.isChild == true
        and row.Content and row.Content.Name and row.Content.ReputationBar
end

local function IsReputationEntryRow(row)
    local data = GetReputationElementData(row)
    return data and data.isHeader ~= true
        and row.Content and row.Content.Name and row.Content.ReputationBar
end

local function IsReputationRowSelected(row)
    if not row or type(row.IsSelected) ~= "function" then return false end
    local ok, selected = pcall(row.IsSelected, row)
    return ok and selected == true or false
end

local function GetReputationRowNativeDecorations(row)
    local regions = {}
    local content = row and row.Content
    local highlight = content and content.BackgroundHighlight
    if highlight then regions[#regions + 1] = highlight end
    return regions
end

local function GetReputationIconColumns(row, includeCollapse)
    local columns = {}
    local content = row and row.Content
    if not content then return columns end

    local accountWide = content.AccountWideIcon
    if accountWide and accountWide.Icon then
        columns[#columns + 1] = {
            kind = "ICON",
            target = accountWide,
            texture = accountWide.Icon,
            borderOwner = accountWide,
            skinOptions = {
                showBorder = false,
                preserveAtlasTexCoords = true,
            },
        }
    end

    if includeCollapse and row.ToggleCollapseButton then
        local collapse = row.ToggleCollapseButton
        local data = GetReputationElementData(row)
        columns[#columns + 1] = {
            kind = "BUTTON",
            target = collapse,
            skinOptions = {
                label = data and data.isCollapsed and "+" or "-",
                textSize = 12,
            },
        }
    end

    local paragon = content.ParagonIcon
    if paragon and paragon.Icon then
        columns[#columns + 1] = {
            kind = "ICON",
            target = paragon,
            texture = paragon.Icon,
            borderOwner = paragon,
            skinOptions = {
                showBorder = false,
                preserveAtlasTexCoords = true,
            },
        }
    end
    return columns
end

local function SkinReputationProgressBar(bar, elementID)
    if not bar then return false end
    local style = NSkin:GetAppearanceStyle(
        "progressBar", IDs.Scope, elementID)
    if not style then return false end
    local border = NSkin:GetAppearanceBorderColor(
        "progressBar", style, IDs.Scope, elementID)
    return NSkin:SkinProgressBar(bar, {
        style = style,
        background = true,
        backgroundColor = style.background,
        borderColor = border,
        useAppearanceTexture = true,
        artworkRegions = { bar.LeftTexture, bar.RightTexture },
        centerText = true,
        textRegions = { bar.BarText },
    }) == true
end


local function GetCurrencyElementData(row)
    if not row then return nil end
    if type(row.GetElementData) == "function" then
        local ok, data = pcall(row.GetElementData, row)
        if ok and data then return data end
    end
    return row.elementData
end

local function IsCurrencySubHeaderRow(row)
    local data = GetCurrencyElementData(row)
    return data and data.isHeader == true
        and tonumber(data.currencyListDepth or 0) > 0
        and row.Text and row.ToggleCollapseButton
end

local function IsCurrencyEntryRow(row)
    local data = GetCurrencyElementData(row)
    return data and data.isHeader ~= true
        and row.Content and row.Content.Name and row.Content.Count
        and row.Content.CurrencyIcon
end

local function IsCurrencyRowSelected(row)
    if not row or type(row.IsSelected) ~= "function" then return false end
    local ok, selected = pcall(row.IsSelected, row)
    return ok and selected == true or false
end

local function GetCurrencyRowNativeDecorations(row)
    local content = row and row.Content
    local highlight = content and content.BackgroundHighlight
    return highlight and { highlight } or {}
end

local function GetCurrencyRowColumns(row, includeCollapse)
    local columns = {}
    if includeCollapse then
        local collapse = row and row.ToggleCollapseButton
        local data = GetCurrencyElementData(row)
        if collapse then
            columns[#columns + 1] = {
                kind = "BUTTON",
                target = collapse,
                skinOptions = {
                    label = data and data.isHeaderExpanded and "-" or "+",
                    textSize = 12,
                },
            }
        end
        if row and row.Text then
            columns[#columns + 1] = {
                kind = "TEXT",
                target = row.Text,
            }
        end
        return columns
    end

    local content = row and row.Content
    if not content then return columns end

    local accountWide = content.AccountWideIcon
    if accountWide and accountWide.Icon then
        columns[#columns + 1] = {
            kind = "ICON",
            target = accountWide,
            texture = accountWide.Icon,
            borderOwner = accountWide,
            skinOptions = {
                showBorder = false,
                preserveAtlasTexCoords = true,
            },
        }
    end

    columns[#columns + 1] = {
        kind = "TEXT",
        target = content.Name,
    }
    columns[#columns + 1] = {
        kind = "TEXT",
        target = content.Count,
    }
    columns[#columns + 1] = {
        kind = "ICON",
        target = content.CurrencyIcon,
        texture = content.CurrencyIcon,
        borderOwner = content,
    }

    -- WatchedCurrencyCheck is a semantic state indicator rather than a
    -- separately editable icon, so leave it Blizzard-owned.
    return columns
end

local function IsCurrencyTransferLogRow(row)
    return row and row.SourceName and row.DestinationName
        and row.CurrencyQuantity and row.CurrencyIcon
end

local function GetTransferLogNativeDecorations(row)
    return row and row.BackgroundHighlight
        and { row.BackgroundHighlight } or {}
end

local function RegisterFlatButton(id, scopeID, label, window, button, priority)
    if not button then return nil end
    return NSkin:RegisterTypedElement("BUTTON", {
        id = id,
        module = "Character",
        appearanceWindowID = scopeID,
        label = label,
        window = window,
        target = button,
        priority = priority,
        skinOptions = {
            label = button.GetText and button:GetText() or "",
        },
        highlightRegions = { button },
        isEditable = function()
            return window:IsVisible() and button:IsVisible()
        end,
    })
end

local function GetRowDecorationRegions(row)
    local regions = {}
    for _, key in ipairs({ "BgTop", "BgBottom", "BgMiddle", "Stripe" }) do
        if row and row[key] then regions[#regions + 1] = row[key] end
    end
    return regions
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
    NSkin:ForEachScrollBoxFrame(scrollBox, function(frame)
        if IsCharacterSectionCard(frame) and frame:IsShown() then
            cards[#cards + 1] = frame
        end
    end)
    return cards
end

local function SkinCharacterSectionCards(scrollBox, elementID, registered)
    if not scrollBox or not scrollBox.ForEachFrame then return false end
    local style = NSkin:GetAppearanceStyle(
        "sectionCard", IDs.Scope, elementID)
    local border = NSkin:GetAppearanceBorderColor(
        "sectionCard", style, IDs.Scope, elementID)
    local applied
    if not NSkin:ForEachScrollBoxFrame(scrollBox, function(frame)
        if IsCharacterSectionCard(frame) then
            NSkin:SkinSectionCard(frame, {
                style = style,
                border = border,
                showBackground = false,
                collapsible = true,
                getExpanded = IsCharacterSectionCardExpanded,
                textRegion = frame.Name,
                artworkRegions = GetCharacterSectionCardArtwork(frame),
            })
            applied = true
        end
    end) then return false end
    if registered then NSkin:NotifySkinningElementBoundsChanged(elementID) end
    return applied == true
end

local function ApplyAuxiliaryWindowChrome(frame, scopeID, windowID,
    headerControlsID, label, title, closeButton)
    if not frame then return false end

    NSkin:SkinStandardWindowChrome({
        frame = frame,
        appearanceWindowID = scopeID,
        elementID = windowID,
        headerControlsID = headerControlsID,
        title = title,
        closeButton = closeButton,
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

    -- CharacterFrame adds its own panel atlas on top of ButtonFrameTemplate.
    -- It is decorative chrome and must not remain visible behind skinned tabs.
    ConcealTexture(frame.Background)

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


local function RegisterCharacterSectionHeader(frame, id, label, header, priority)
    if not header or not header.Title then return false end

    local function Refresh()
        ConcealTexture(header.Background)
        local style = NSkin:GetAppearanceStyle("text", IDs.Scope, id)
        return NSkin:SkinText(header.Title, style) ~= nil
    end

    local registered = NSkin:RegisterSkinningElement(id, {
        module = "Character",
        appearanceWindowID = IDs.Scope,
        label = label,
        kind = "SECTION_HEADER",
        window = frame,
        target = header,
        priority = priority,
        draggable = false,
        appearanceStyles = { "text" },
        appearanceTypeIDs = { "TEXT" },
        highlightRegions = { header },
        refreshAppearance = Refresh,
        refreshLayout = Refresh,
        isEditable = function()
            return frame:IsVisible() and header:IsVisible()
        end,
    })
    Refresh()
    return registered == true
end

function CharacterSkin:ApplyPaperDollStats(frame)
    local pane = _G.CharacterStatsPane
    if not frame or not pane then return false end

    -- Remove only audited decorative art. Shared elements below provide the
    -- replacement hierarchy instead of recursively hiding unknown textures.
    ConcealTexture(pane.ClassBackground)

    local applied = false

    local itemLevelHeader = pane.ItemLevelCategory
    local itemLevelFrame = pane.ItemLevelFrame
    local itemLevelTitle = itemLevelHeader and itemLevelHeader.Title
    local itemLevelValue = itemLevelFrame and itemLevelFrame.Value
    if itemLevelHeader and itemLevelFrame and itemLevelTitle and itemLevelValue then
        local function RefreshItemLevel()
            ConcealTexture(itemLevelHeader.Background)
            ConcealTexture(itemLevelFrame.Background)
            local style = NSkin:GetAppearanceStyle(
                "text", IDs.Scope, IDs.PaperDoll.Stats.ItemLevelHeader)
            local changed = NSkin:SkinText(itemLevelTitle, style) == true
            changed = NSkin:SkinText(itemLevelValue, style) == true or changed
            NSkin:NotifySkinningElementBoundsChanged(
                IDs.PaperDoll.Stats.ItemLevelHeader)
            return changed
        end

        applied = NSkin:RegisterSkinningElement(
            IDs.PaperDoll.Stats.ItemLevelHeader, {
                module = "Character",
                appearanceWindowID = IDs.Scope,
                label = "Item level",
                kind = "TEXT",
                window = frame,
                target = itemLevelHeader,
                priority = 64,
                draggable = false,
                appearanceStyles = { "text" },
                appearanceTypeIDs = { "TEXT" },
                editorOptions = {
                    { id = "shared.textAppearance", label = "Text",
                        category = "CUSTOMIZE" },
                },
                composition = {
                    mode = "COMPOSITE",
                    movementOwner = itemLevelHeader,
                    members = {
                        { kind = "TEXT", role = "PRIMARY",
                            target = itemLevelTitle, label = "Label" },
                        { kind = "TEXT", role = "SECONDARY",
                            target = itemLevelValue, label = "Value" },
                    },
                },
                highlightRegions = { itemLevelHeader, itemLevelFrame },
                refreshAppearance = RefreshItemLevel,
                refreshLayout = RefreshItemLevel,
                isEditable = function()
                    return frame:IsVisible() and pane:IsVisible()
                        and itemLevelHeader:IsVisible()
                        and itemLevelFrame:IsVisible()
                end,
            }) == true or applied

        -- Preserve the old canonical value ID as a structural child so existing
        -- references remain valid, while Skinning Mode exposes only the parent
        -- Item Level composite.
        NSkin:RegisterSkinningElement(IDs.PaperDoll.Stats.ItemLevelValue, {
            module = "Character",
            appearanceWindowID = IDs.Scope,
            label = "Item level value",
            kind = "TEXT",
            window = frame,
            target = itemLevelValue,
            priority = 67,
            draggable = false,
            compositionParentID = IDs.PaperDoll.Stats.ItemLevelHeader,
            highlightRegions = { itemLevelFrame },
            refreshAppearance = RefreshItemLevel,
            refreshLayout = RefreshItemLevel,
            isEditable = function()
                return frame:IsVisible() and pane:IsVisible()
                    and itemLevelFrame:IsVisible()
            end,
        })
        RefreshItemLevel()
    end

    applied = RegisterCharacterSectionHeader(
        frame, IDs.PaperDoll.Stats.AttributesHeader,
        "Attributes header", pane.AttributesCategory, 65) or applied
    applied = RegisterCharacterSectionHeader(
        frame, IDs.PaperDoll.Stats.EnhancementsHeader,
        "Enhancements header", pane.EnhancementsCategory, 66) or applied

    local function RefreshRows()
        local style = NSkin:GetAppearanceStyle(
            "row", IDs.Scope, IDs.PaperDoll.Stats.Rows)
        local border = NSkin:GetAppearanceBorderColor(
            "row", style, IDs.Scope, IDs.PaperDoll.Stats.Rows)
        local changed = false
        for _, row in ipairs(GetDirectStatRows(pane, false)) do
            changed = NSkin:SkinRow(row, {
                style = style,
                border = border,
                surfaceInset = 0,
                nativeDecorationRegions = { row.Background },
                getHovered = IsRowHovered,
                columns = {
                    { kind = "TEXT", target = row.Label },
                    { kind = "TEXT", target = row.Value },
                },
                elementID = IDs.PaperDoll.Stats.Rows,
                appearanceWindowID = IDs.Scope,
            }) ~= nil or changed
        end
        NSkin:NotifySkinningElementBoundsChanged(IDs.PaperDoll.Stats.Rows)
        return changed
    end

    NSkin:RegisterSkinningElement(IDs.PaperDoll.Stats.Rows, {
        module = "Character",
        appearanceWindowID = IDs.Scope,
        label = "Character stat rows",
        kind = "ROW",
        window = frame,
        target = pane,
        priority = 68,
        draggable = false,
        appearanceStyles = { "row", "text" },
        appearanceTypeIDs = { "ROW", "TEXT" },
        editorOptions = {
            { id = "shared.rowAppearance", label = "Row",
                category = "CUSTOMIZE" },
            { id = "shared.textAppearance", label = "Text",
                category = "CUSTOMIZE" },
        },
        highlightRegions = function()
            return GetDirectStatRows(pane, true)
        end,
        pixelBorderTargets = function()
            return GetDirectStatRows(pane, true)
        end,
        refreshAppearance = RefreshRows,
        refreshLayout = RefreshRows,
        isEditable = function()
            return frame:IsVisible() and pane:IsVisible()
                and #GetDirectStatRows(pane, true) > 0
        end,
    })
    applied = RefreshRows() or applied

    return applied
end

function CharacterSkin:ApplyPaperDollSkin(frame)
    local paperDoll = _G.PaperDollFrame
    local modelScene = _G.CharacterModelScene
    if not frame or not paperDoll or not modelScene then return false end

    if frame.Inset then
        NSkin:ConcealWindowArtwork(frame.Inset)
    end
    if _G.CharacterFrameInset then
        NSkin:ConcealWindowArtwork(_G.CharacterFrameInset)
    end
    if _G.CharacterFrameInsetRight then
        NSkin:ConcealWindowArtwork(_G.CharacterFrameInsetRight)
    end
    ConcealTexture(_G.CharacterFrameInsetBG)

    for _, name in ipairs(PAPER_DOLL_INNER_BORDER_NAMES) do
        ConcealTexture(_G[name])
    end

    local sidebarTabs = _G.PaperDollSidebarTabs
    if sidebarTabs then
        ConcealTexture(sidebarTabs.DecorLeft)
        ConcealTexture(sidebarTabs.DecorRight)
    end

    local preserveModel = {
        [modelScene.BackgroundTopLeft] = true,
        [modelScene.BackgroundTopRight] = true,
        [modelScene.BackgroundBotLeft] = true,
        [modelScene.BackgroundBotRight] = true,
        [modelScene.BackgroundOverlay] = true,
    }

    if modelScene.GetRegions then
        for _, region in ipairs({ modelScene:GetRegions() }) do
            if region and region.GetObjectType
                and region:GetObjectType() == "Texture"
                and not preserveModel[region]
            then
                ConcealTexture(region)
            end
        end
    end

    local applied = false

    if _G.CharacterLevelText then
        local levelText = NSkin:RegisterTextElement({
            id = IDs.PaperDoll.LevelText,
            module = "Character",
            appearanceWindowID = IDs.Scope,
            label = "Character level and specialization",
            window = frame,
            target = _G.CharacterLevelText,
            priority = 59,
            highlightRegions = { _G.CharacterLevelText },
            isEditable = function()
                return frame:IsVisible() and paperDoll:IsVisible()
                    and _G.CharacterLevelText:IsVisible()
            end,
        })
        if levelText then NSkin:RefreshTypedElementAppearance(levelText) end
        applied = levelText ~= nil or applied
    end

    -- Keep stable per-slot ICON registrations for lifecycle/reset ownership,
    -- but expose them as three editor/appearance anchor groups matching the
    -- Blizzard paper-doll layout: left, right, and bottom.
    for _, descriptor in ipairs(GetPaperDollSlots(false)) do
        local slot = descriptor.frame
        local icon = GetPaperDollSlotTexture(slot)
        if icon then
            local element = NSkin:RegisterIcon({
                id = IDs.PaperDoll.EquipmentSlotPrefix .. descriptor.key,
                module = "Character",
                appearanceWindowID = IDs.Scope,
                label = descriptor.label .. " equipment slot",
                window = frame,
                target = slot,
                anchorGroupID = IDs.PaperDoll.EquipmentGroups[descriptor.group],
                anchorGroupLabel = PAPER_DOLL_GROUP_LABELS[descriptor.group],
                anchorGroupAppearanceSource = IDs.PaperDoll.EquipmentSlotPrefix
                    .. PAPER_DOLL_GROUP_APPEARANCE_SOURCE[descriptor.group],
                texture = icon,
                borderOwner = slot,
                qualityProvider = GetPaperDollSlotQuality,
                nativeDecorationRegions =
                    GetPaperDollSlotDecorations(slot, icon),
                priority = 60,
                isEditable = function()
                    return frame:IsVisible() and paperDoll:IsVisible()
                        and slot:IsVisible()
                end,
            })
            applied = element ~= nil or applied
        end
    end

    applied = self:ApplyPaperDollStats(frame) or applied
    return applied
end

local function StylePaperDollSideTabArtwork(tab)
    if not tab then return end
    ConcealTexture(tab.TabBg)
    ConcealTexture(tab.Hider)
    ConcealTexture(tab.Highlight)
end

function CharacterSkin:ApplyPaperDollSideTabs(frame)
    local paperDoll = _G.PaperDollFrame
    local owner = _G.PaperDollSidebarTabs
    if not frame or not paperDoll or not owner then return false end

    local tabs = {
        _G.PaperDollSidebarTab1,
        _G.PaperDollSidebarTab2,
        _G.PaperDollSidebarTab3,
    }
    for _, tab in ipairs(tabs) do
        if not tab then return false end
        StylePaperDollSideTabArtwork(tab)
    end

    local element = NSkin:RegisterSideTabGroup(IDs.PaperDoll.SideTabs, {
        module = "Character",
        appearanceWindowID = IDs.Scope,
        label = "Character sidebar tabs",
        window = frame,
        target = tabs[1],
        targets = tabs,
        priority = 70,
        isEditable = function()
            return frame:IsVisible() and paperDoll:IsVisible()
                and owner:IsVisible()
        end,
    })
    return element ~= nil
end

function CharacterSkin:ApplyTitleRows(frame, titles)
    local scrollBox = titles and titles.ScrollBox
    if not frame or not titles or not scrollBox then return false end

    local function Refresh()
        local style = NSkin:GetAppearanceStyle(
            "row", IDs.Scope, IDs.Titles.Rows)
        local border = NSkin:GetAppearanceBorderColor(
            "row", style, IDs.Scope, IDs.Titles.Rows)
        local applied = false
        NSkin:ForEachScrollBoxFrame(scrollBox, function(row)
            if IsTitleRow(row) then
                applied = NSkin:SkinRow(row, {
                    style = style,
                    border = border,
                    surfaceInset = 0,
                    nativeDecorationRegions = GetRowDecorationRegions(row),
                    hoverRegion = row.GetHighlightTexture
                        and row:GetHighlightTexture() or nil,
                    getHovered = IsRowHovered,
                    selectedRegion = row.SelectedBar,
                    columns = {
                        { kind = "TEXT", target = row.text },
                    },
                    elementID = IDs.Titles.Rows,
                    appearanceWindowID = IDs.Scope,
                }) ~= nil or applied
            end
        end)
        NSkin:NotifySkinningElementBoundsChanged(IDs.Titles.Rows)
        return applied
    end

    NSkin:RegisterSkinningElement(IDs.Titles.Rows, {
        module = "Character",
        appearanceWindowID = IDs.Scope,
        label = "Character title rows",
        kind = "ROW",
        window = frame,
        target = scrollBox,
        priority = 80,
        draggable = false,
        appearanceStyles = { "row", "text" },
        appearanceTypeIDs = { "ROW", "TEXT" },
        editorOptions = {
            { id = "shared.rowAppearance", label = "Row",
                category = "CUSTOMIZE" },
            { id = "shared.textAppearance", label = "Text",
                category = "CUSTOMIZE" },
        },
        highlightRegions = function()
            return GetVisibleScrollBoxRows(scrollBox, IsTitleRow)
        end,
        pixelBorderTargets = function()
            return GetVisibleScrollBoxRows(scrollBox, IsTitleRow)
        end,
        refreshAppearance = Refresh,
        refreshLayout = Refresh,
        isEditable = function()
            return frame:IsVisible() and titles:IsVisible()
                and #GetVisibleScrollBoxRows(scrollBox, IsTitleRow) > 0
        end,
    })
    HookScrollBoxRefresh(scrollBox, Refresh)
    return Refresh()
end

function CharacterSkin:ApplyEquipmentManagerRows(frame, equipment)
    local scrollBox = equipment and equipment.ScrollBox
    if not frame or not equipment or not scrollBox then return false end

    local function Refresh()
        local style = NSkin:GetAppearanceStyle(
            "row", IDs.Scope, IDs.Equipment.Rows)
        local border = NSkin:GetAppearanceBorderColor(
            "row", style, IDs.Scope, IDs.Equipment.Rows)
        local applied = false
        NSkin:ForEachScrollBoxFrame(scrollBox, function(row)
            if IsEquipmentRow(row) then
                local columns = {
                    {
                        kind = "ICON",
                        target = row.icon,
                        texture = row.icon,
                        borderOwner = row,
                    },
                    { kind = "TEXT", target = row.text },
                }
                if row.SpecIcon then
                    columns[#columns + 1] = {
                        kind = "ICON",
                        target = row.SpecIcon,
                        texture = row.SpecIcon,
                        borderOwner = row,
                        nativeDecorationRegions = row.SpecRing
                            and { row.SpecRing } or nil,
                    }
                end
                if row.EditButton and row.EditButton.texture then
                    columns[#columns + 1] = {
                        kind = "ICON",
                        target = row.EditButton,
                        texture = row.EditButton.texture,
                        borderOwner = row.EditButton,
                    }
                end
                if row.DeleteButton and row.DeleteButton.texture then
                    columns[#columns + 1] = {
                        kind = "ICON",
                        target = row.DeleteButton,
                        texture = row.DeleteButton.texture,
                        borderOwner = row.DeleteButton,
                    }
                end

                applied = NSkin:SkinRow(row, {
                    style = style,
                    border = border,
                    nativeDecorationRegions = GetRowDecorationRegions(row),
                    hoverRegion = row.HighlightBar,
                    getHovered = IsRowHovered,
                    selectedRegion = row.SelectedBar,
                    columns = columns,
                    elementID = IDs.Equipment.Rows,
                    appearanceWindowID = IDs.Scope,
                }) ~= nil or applied
            end
        end)
        NSkin:NotifySkinningElementBoundsChanged(IDs.Equipment.Rows)
        return applied
    end

    NSkin:RegisterSkinningElement(IDs.Equipment.Rows, {
        module = "Character",
        appearanceWindowID = IDs.Scope,
        label = "Equipment manager rows",
        kind = "ROW",
        window = frame,
        target = scrollBox,
        priority = 81,
        draggable = false,
        appearanceStyles = { "row", "text", "icon" },
        appearanceTypeIDs = { "ROW", "TEXT", "ICON" },
        editorOptions = {
            { id = "shared.rowAppearance", label = "Row",
                category = "CUSTOMIZE" },
            { id = "shared.textAppearance", label = "Text",
                category = "CUSTOMIZE" },
            { id = "shared.iconAppearance", label = "Icons",
                category = "CUSTOMIZE" },
        },
        highlightRegions = function()
            return GetVisibleScrollBoxRows(scrollBox, IsEquipmentRow)
        end,
        pixelBorderTargets = function()
            return GetVisibleScrollBoxRows(scrollBox, IsEquipmentRow)
        end,
        refreshAppearance = Refresh,
        refreshLayout = Refresh,
        isEditable = function()
            return frame:IsVisible() and equipment:IsVisible()
                and #GetVisibleScrollBoxRows(scrollBox, IsEquipmentRow) > 0
        end,
    })
    HookScrollBoxRefresh(scrollBox, Refresh)
    return Refresh()
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

    local applied = self:ApplyPaperDollSideTabs(frame)
    applied = self:ApplyTitleRows(frame, titles) or applied
    applied = self:ApplyEquipmentManagerRows(frame, equipment) or applied

    applied = NSkin:RegisterScrollBar({
        id = IDs.Titles.ScrollBar, module = "Character",
        appearanceWindowID = IDs.Scope,
        label = "Character titles scroll bar", window = frame,
        target = titleScrollBar, priority = 82,
        highlightRegions = { titleScrollBar },
        isEditable = function()
            return frame:IsVisible() and titles:IsVisible()
                and titleScrollBar:IsVisible()
        end,
    }) ~= nil or applied

    applied = NSkin:RegisterScrollBar({
        id = IDs.Equipment.ScrollBar, module = "Character",
        appearanceWindowID = IDs.Scope,
        label = "Equipment manager scroll bar", window = frame,
        target = equipmentScrollBar, priority = 83,
        highlightRegions = { equipmentScrollBar },
        isEditable = function()
            return frame:IsVisible() and equipment:IsVisible()
                and equipmentScrollBar:IsVisible()
        end,
    }) ~= nil or applied

    applied = NSkin:RegisterTypedElement("BUTTON", {
        id = IDs.Equipment.EquipButton, module = "Character",
        appearanceWindowID = IDs.Scope,
        label = "Equipment manager equip button", window = frame,
        target = equipButton, priority = 84,
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
        target = saveButton, priority = 85,
        highlightRegions = { saveButton },
        isEditable = function()
            return frame:IsVisible() and equipment:IsVisible()
                and saveButton:IsVisible()
        end,
    }) ~= nil or applied

    -- ModelSceneControlFrame glyphs are atlas-backed. The current ICON shared
    -- component rewrites texcoords, so registering these as ICON children would
    -- corrupt their atlas presentation. Keep the Blizzard camera controls
    -- untouched until ICON gains a generic preserve-native-texcoords option.

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

function CharacterSkin:ApplyReputationRows(frame)
    local reputation = _G.ReputationFrame
    local scrollBox = reputation and reputation.ScrollBox
    if not frame or not reputation or not scrollBox then return false end

    local function RefreshFamily(elementID, predicate, includeCollapse)
        local resolvedRowStyle = NSkin:GetAppearanceStyle(
            "row", IDs.Scope, elementID)
        local rowStyle = {}
        for key, value in pairs(resolvedRowStyle or {}) do
            rowStyle[key] = value
        end
        -- Reputation entries are list records rather than boxed cards. Keep
        -- their default presentation borderless while retaining ROW-owned
        -- background/hover/selection behavior.
        rowStyle.borderSize = 0
        local rowBorder = NSkin:GetAppearanceBorderColor(
            "row", rowStyle, IDs.Scope, elementID)
        local applied = false

        NSkin:ForEachScrollBoxFrame(scrollBox, function(row)
            if not predicate(row) then return end
            local content = row.Content
            local columns = GetReputationIconColumns(row, includeCollapse)
            columns[#columns + 1] = {
                kind = "TEXT",
                target = content.Name,
            }

            local rowState = NSkin:SkinRow(row, {
                style = rowStyle,
                border = rowBorder,
                showBackground = false,
                nativeDecorationRegions = GetReputationRowNativeDecorations(row),
                getHovered = IsRowHovered,
                getSelected = IsReputationRowSelected,
                columns = columns,
                elementID = elementID,
                appearanceWindowID = IDs.Scope,
            })
            if rowState and rowState.border then
                NSkin:SetPixelBorderShown(rowState.border, false)
            end
            applied = rowState ~= nil or applied

            applied = SkinReputationProgressBar(
                content.ReputationBar, elementID) or applied
        end)

        NSkin:NotifySkinningElementBoundsChanged(elementID)
        return applied
    end

    local function RegisterFamily(elementID, label, predicate, includeCollapse,
        priority)
        local registeredFlag = elementID == IDs.ReputationSubHeaderRows
            and reputationSubHeaderRowsRegistered or reputationRowsRegistered
        if not registeredFlag then
            local registered = NSkin:RegisterSkinningElement(elementID, {
                module = "Character",
                appearanceWindowID = IDs.Scope,
                label = label,
                kind = "ROW",
                window = frame,
                target = scrollBox,
                priority = priority,
                draggable = false,
                appearanceStyles = { "row", "text", "icon", "progressBar" },
                appearanceTypeIDs = { "ROW", "TEXT", "ICON", "PROGRESS_BAR" },
                editorOptions = {
                    { id = "shared.rowAppearance", label = "Row",
                        category = "CUSTOMIZE" },
                    { id = "shared.textAppearance", label = "Text",
                        category = "CUSTOMIZE" },
                    { id = "shared.iconAppearance", label = "Icons",
                        category = "CUSTOMIZE" },
                },
                highlightRegions = function()
                    return GetVisibleScrollBoxRows(scrollBox, predicate)
                end,
                pixelBorderTargets = function()
                    return GetVisibleScrollBoxRows(scrollBox, predicate)
                end,
                refreshAppearance = function()
                    return RefreshFamily(elementID, predicate, includeCollapse)
                end,
                refreshLayout = function()
                    return RefreshFamily(elementID, predicate, includeCollapse)
                end,
                isEditable = function()
                    return frame:IsVisible() and reputation:IsVisible()
                        and #GetVisibleScrollBoxRows(scrollBox, predicate) > 0
                end,
            }) == true
            if elementID == IDs.ReputationSubHeaderRows then
                reputationSubHeaderRowsRegistered = registered
            else
                reputationRowsRegistered = registered
            end
        end
        return RefreshFamily(elementID, predicate, includeCollapse)
    end

    local applied = RegisterFamily(
        IDs.ReputationSubHeaderRows, "Reputation subheader rows",
        IsReputationSubHeaderRow, true, 87)
    applied = RegisterFamily(
        IDs.ReputationRows, "Reputation faction rows",
        IsReputationEntryRow, false, 88) or applied
    return applied
end

function CharacterSkin:ApplyReputationDropdown(frame)
    local reputation = _G.ReputationFrame
    local scrollBox = reputation and reputation.ScrollBox
    local dropdown = reputation and reputation.filterDropdown
    -- WowScrollBoxList contributes its own edge/shadow backdrop. It is
    -- decorative chrome and otherwise remains visible behind the skinned rows.
    if scrollBox then
        ConcealTexture(scrollBox.Shadows or scrollBox.shadows)
    end
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
    applied = self:ApplyReputationRows(frame) or applied
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
            CharacterSkin:ApplyReputationRows(frame)
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

function CharacterSkin:ApplyCurrencyRows(frame)
    local currency = _G.TokenFrame
    local scrollBox = currency and currency.ScrollBox
    if not frame or not currency or not scrollBox then return false end

    local function RefreshFamily(elementID, predicate, includeCollapse)
        local resolvedRowStyle = NSkin:GetAppearanceStyle(
            "row", IDs.Scope, elementID)
        local rowStyle = {}
        for key, value in pairs(resolvedRowStyle or {}) do
            rowStyle[key] = value
        end
        -- Currency entries are lightweight list records. Keep their default
        -- presentation borderless while ROW owns background/hover/selection.
        rowStyle.borderSize = 0
        local rowBorder = NSkin:GetAppearanceBorderColor(
            "row", rowStyle, IDs.Scope, elementID)
        local applied = false

        NSkin:ForEachScrollBoxFrame(scrollBox, function(row)
            if not predicate(row) then return end
            local rowState = NSkin:SkinRow(row, {
                style = rowStyle,
                border = rowBorder,
                showBackground = false,
                nativeDecorationRegions = GetCurrencyRowNativeDecorations(row),
                getHovered = IsRowHovered,
                getSelected = includeCollapse and nil or IsCurrencyRowSelected,
                columns = GetCurrencyRowColumns(row, includeCollapse),
                elementID = elementID,
                appearanceWindowID = IDs.Scope,
            })
            if rowState and rowState.border then
                NSkin:SetPixelBorderShown(rowState.border, false)
            end
            applied = rowState ~= nil or applied
        end)

        NSkin:NotifySkinningElementBoundsChanged(elementID)
        return applied
    end

    local function RegisterFamily(elementID, label, predicate, includeCollapse,
        priority)
        local registeredFlag = elementID == IDs.CurrencySubHeaderRows
            and currencySubHeaderRowsRegistered or currencyRowsRegistered
        if not registeredFlag then
            local registered = NSkin:RegisterSkinningElement(elementID, {
                module = "Character",
                appearanceWindowID = IDs.Scope,
                label = label,
                kind = "ROW",
                window = frame,
                target = scrollBox,
                priority = priority,
                draggable = false,
                appearanceStyles = { "row", "text", "icon" },
                appearanceTypeIDs = { "ROW", "TEXT", "ICON" },
                editorOptions = {
                    { id = "shared.rowAppearance", label = "Row",
                        category = "CUSTOMIZE" },
                    { id = "shared.textAppearance", label = "Text",
                        category = "CUSTOMIZE" },
                    { id = "shared.iconAppearance", label = "Icons",
                        category = "CUSTOMIZE" },
                },
                highlightRegions = function()
                    return GetVisibleScrollBoxRows(scrollBox, predicate)
                end,
                pixelBorderTargets = function()
                    return GetVisibleScrollBoxRows(scrollBox, predicate)
                end,
                refreshAppearance = function()
                    return RefreshFamily(elementID, predicate, includeCollapse)
                end,
                refreshLayout = function()
                    return RefreshFamily(elementID, predicate, includeCollapse)
                end,
                isEditable = function()
                    return frame:IsVisible() and currency:IsVisible()
                        and #GetVisibleScrollBoxRows(scrollBox, predicate) > 0
                end,
            }) == true
            if elementID == IDs.CurrencySubHeaderRows then
                currencySubHeaderRowsRegistered = registered
            else
                currencyRowsRegistered = registered
            end
        end
        return RefreshFamily(elementID, predicate, includeCollapse)
    end

    local applied = RegisterFamily(
        IDs.CurrencySubHeaderRows, "Currency subheader rows",
        IsCurrencySubHeaderRow, true, 89)
    applied = RegisterFamily(
        IDs.CurrencyRows, "Currency rows",
        IsCurrencyEntryRow, false, 90) or applied
    return applied
end

function CharacterSkin:ApplyCurrencyDropdown(frame)
    local currency = _G.TokenFrame
    local scrollBox = currency and currency.ScrollBox
    local dropdown = currency and currency.filterDropdown
    local transferLogButton = currency and currency.CurrencyTransferLogToggleButton

    if scrollBox then
        ConcealTexture(scrollBox.Shadows or scrollBox.shadows)
    end

    local dropdownElement = NSkin:RegisterDropdown({
        id = IDs.CurrencyDropdown, module = "Character",
        appearanceWindowID = IDs.Scope,
        label = "Currency filter and transfer log", window = frame,
        target = dropdown, menus = { "MENU_CURRENCY_FRAME_FILTER" },
        priority = 85,
        highlightRegions = { dropdown },
        isEditable = function()
            return frame:IsVisible() and currency:IsVisible()
                and dropdown:IsVisible()
        end,
    })
    local applied = dropdownElement ~= nil

    if transferLogButton then
        local normalTexture = transferLogButton.GetNormalTexture
            and transferLogButton:GetNormalTexture()
            or transferLogButton.NormalTexture
        local pushedTexture = transferLogButton.GetPushedTexture
            and transferLogButton:GetPushedTexture()
            or transferLogButton.PushedTexture
        local highlightTexture = transferLogButton.GetHighlightTexture
            and transferLogButton:GetHighlightTexture()
            or transferLogButton.HighlightTexture

        -- Keep Blizzard's 22x22 button unchanged as the interaction/anchor owner.
        -- A larger mouse-transparent visual frame provides enough room for the
        -- custom scroll icon and its border without shifting Blizzard layout.
        -- The icon itself stays smaller than the border anchor so edge detail is
        -- not covered by the 1px border (especially the scroll top/bottom curls).
        local visual = transferLogButton.NSkinTransferLogVisual
        if not visual and _G.CreateFrame then
            visual = _G.CreateFrame("Frame", nil, transferLogButton)
            visual:EnableMouse(false)
            visual:SetSize(32, 32)
            visual:SetPoint("CENTER", transferLogButton, "CENTER", 0, 0)
            if visual.SetFrameLevel and transferLogButton.GetFrameLevel then
                visual:SetFrameLevel(transferLogButton:GetFrameLevel() + 1)
            end
            transferLogButton.NSkinTransferLogVisual = visual
        end

        local presentation = transferLogButton.NSkinTransferLogIcon
        if visual and not presentation and visual.CreateTexture then
            presentation = visual:CreateTexture(nil, "ARTWORK", nil, 7)
            presentation:SetSize(20, 20)
            presentation:SetPoint("CENTER", visual, "CENTER", 0, 0)
            presentation:SetTexture(NSkin.mediaPath .. "ancient-scroll.png")
            NSkin:ConfigureOwnedPixelTexture(presentation)
            transferLogButton.NSkinTransferLogIcon = presentation
        end

        if presentation and visual then
            visual:ClearAllPoints()
            visual:SetPoint("CENTER", transferLogButton, "CENTER", 0, 0)
            visual:SetSize(32, 32)
            visual:Show()

            presentation:ClearAllPoints()
            presentation:SetPoint("CENTER", visual, "CENTER", 0, 0)
            presentation:SetSize(20, 20)
            presentation:SetTexture(NSkin.mediaPath .. "ancient-scroll.png")
            presentation:Show()

            local function RefreshTransferLogIcon()
                local iconStyle = NSkin:GetAppearanceStyle(
                    "icon", IDs.Scope, IDs.CurrencyDropdown)
                NSkin:SkinIcon(transferLogButton, {
                    texture = presentation,
                    borderOwner = visual,
                    style = iconStyle,
                    width = 20,
                    height = 20,
                    crop = 1,
                    zoom = 0,
                    showBorder = true,
                    borderSize = 1,
                    borderPadding = 4,
                    borderMode = "fixed",
                    preserveTexCoords = true,
                    nativeDecorationRegions = {
                        normalTexture, pushedTexture, highlightTexture,
                    },
                })
                return true
            end

            RefreshTransferLogIcon()

            -- The dropdown and transfer-log icon are one logical editor control.
            -- DROPDOWN remains the primary/movement owner; ICON contributes its
            -- canonical appearance options as the secondary composite member.
            if dropdownElement then
                dropdownElement.composition = {
                    mode = "COMPOSITE",
                    movementOwner = dropdown,
                    members = {
                        { kind = "DROPDOWN", role = "PRIMARY",
                            target = dropdown, label = "Filter" },
                        { kind = "ICON", role = "SECONDARY",
                            target = visual, label = "Transfer Log" },
                    },
                }
                dropdownElement.highlightRegions = { dropdown, visual }
                local originalRefreshAppearance = dropdownElement.refreshAppearance
                local originalRefreshLayout = dropdownElement.refreshLayout
                dropdownElement.refreshAppearance = function(owner, element)
                    local refreshed = originalRefreshAppearance
                        and originalRefreshAppearance(owner, element)
                    RefreshTransferLogIcon()
                    return refreshed ~= false
                end
                dropdownElement.refreshLayout = function(owner, element)
                    local refreshed = originalRefreshLayout
                        and originalRefreshLayout(owner, element)
                    RefreshTransferLogIcon()
                    NSkin:NotifySkinningElementBoundsChanged(element.id)
                    return refreshed ~= false
                end
                NSkin:InitializeElementComposition(dropdownElement)
            end
        end
    end

    applied = NSkin:RegisterScrollBar({
        id = IDs.CurrencyScrollBar, module = "Character",
        appearanceWindowID = IDs.Scope,
        label = "Currency scroll bar", window = frame,
        target = currency and currency.ScrollBar, priority = 87,
        highlightRegions = { currency and currency.ScrollBar },
        isEditable = function()
            return frame:IsVisible() and currency:IsVisible()
                and currency.ScrollBar:IsVisible()
        end,
    }) or applied

    applied = SkinCharacterSectionCards(scrollBox,
        IDs.CurrencySectionCards, currencySectionCardsRegistered) or applied
    applied = self:ApplyCurrencyRows(frame) or applied

    if scrollBox and not currencySectionCardsRegistered then
        currencySectionCardsRegistered = NSkin:RegisterSkinningElement(
            IDs.CurrencySectionCards, {
                module = "Character",
                appearanceWindowID = IDs.Scope,
                label = "Currency section cards",
                kind = "SECTION_CARD",
                window = frame,
                target = scrollBox,
                priority = 88,
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
            CharacterSkin:ApplyCurrencyRows(frame)
        end)
        currencySectionCardsHooked = true
    end

    if applied then HookOwnerRefresh(currency) end
    return applied ~= nil
end

function CharacterSkin:ApplyCurrencyOptions()
    local popup = _G.TokenFramePopup
    if not popup then return false end

    NSkin:ConcealWindowArtwork(popup.Border)
    local popupCloseButton = popup.CloseButton
        or popup["$parent.CloseButton"]
        or _G.TokenFramePopupCloseButton
    local applied = ApplyAuxiliaryWindowChrome(
        popup, IDs.CurrencyOptions.Scope, IDs.CurrencyOptions.Window,
        IDs.CurrencyOptions.HeaderControls, "Currency Options window",
        popup.Title, popupCloseButton)

    local unused = popup.InactiveCheckbox
    local backpack = popup.BackpackCheckbox
    local transfer = popup.CurrencyTransferToggleButton
    applied = NSkin:RegisterCheckbox({
        id = IDs.CurrencyOptions.UnusedCheckbox, module = "Character",
        appearanceWindowID = IDs.CurrencyOptions.Scope,
        label = "Show unused currencies", window = popup,
        target = unused, text = GetCheckboxText(unused), priority = 70,
        skinOptions = { visualSize = 14 },
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
        skinOptions = { visualSize = 14 },
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

local function GetTransferRowStyle(scopeID, elementID)
    local resolved = NSkin:GetAppearanceStyle("row", scopeID, elementID)
    local style = {}
    for key, value in pairs(resolved or {}) do
        style[key] = value
    end
    -- Transfer rows are lightweight layout records, not boxed cards. Keep the
    -- default presentation borderless while retaining ROW-owned background.
    style.borderSize = 0
    return style, NSkin:GetAppearanceBorderColor(
        "row", style, scopeID, elementID)
end

local function RegisterCurrencyTransferRow(definition)
    local row = definition.target
    if not row then return nil end

    local function Refresh()
        local rowStyle, rowBorder = GetTransferRowStyle(
            IDs.CurrencyTransfer.Scope, definition.id)

        local rowState = NSkin:SkinRow(row, {
            style = rowStyle,
            border = rowBorder,
            showBackground = false,
            columns = definition.columns,
            elementID = definition.id,
            appearanceWindowID = IDs.CurrencyTransfer.Scope,
        })
        if rowState and rowState.border then
            NSkin:SetPixelBorderShown(rowState.border, false)
        end

        for _, child in ipairs(definition.extraSkins or {}) do
            if child.target then
                local childDefinition = {
                    id = definition.id,
                    appearanceWindowID = IDs.CurrencyTransfer.Scope,
                    target = child.target,
                    skinOptions = child.skinOptions,
                    menus = child.menus,
                }
                NSkin:SkinTypedElement(child.kind, childDefinition)
            end
        end

        NSkin:NotifySkinningElementBoundsChanged(definition.id)
        return true
    end

    local members = {
        { kind = "ROW", role = "PRIMARY", target = row, label = "Row" },
    }
    for _, member in ipairs(definition.members or {}) do
        members[#members + 1] = member
    end

    local element = NSkin:RegisterSkinningElement(definition.id, {
        module = "Character",
        appearanceWindowID = IDs.CurrencyTransfer.Scope,
        label = definition.label,
        kind = "ROW",
        window = definition.window,
        target = row,
        priority = definition.priority,
        composition = {
            mode = "COMPOSITE",
            movementOwner = row,
            members = members,
        },
        highlightRegions = definition.highlightRegions,
        refreshAppearance = Refresh,
        refreshLayout = Refresh,
        isEditable = function()
            return definition.window:IsVisible() and row:IsVisible()
        end,
    })
    Refresh()
    return element
end

local function ApplyTransferDirectionArrow(sourceSelector)
    local dropdown = sourceSelector and sourceSelector.Dropdown
    local nativeArrow = dropdown and dropdown.LongArrow
    if nativeArrow then ConcealTexture(nativeArrow) end
    if not sourceSelector or not sourceSelector.CreateTexture then return end

    local arrow = sourceSelector.NSkinTransferDirectionArrow
    if not arrow then
        arrow = sourceSelector:CreateTexture(nil, "OVERLAY", nil, 7)
        arrow:SetSize(22, 22)
        arrow:SetTexture(NSkin.mediaPath .. "angle-small-down.png")
        -- The media asset points down by default; WoW texture rotation uses
        -- positive pi/2 here for the source-to-destination direction.
        arrow:SetRotation(math.pi / 2)
        arrow:SetPoint("CENTER", sourceSelector, "CENTER", 0, 0)
        NSkin:ConfigureOwnedPixelTexture(arrow)
        sourceSelector.NSkinTransferDirectionArrow = arrow
    end
    local textStyle = NSkin:GetAppearanceStyle(
        "text", IDs.CurrencyTransfer.Scope, IDs.CurrencyTransfer.SourceRow)
    local color = NSkin:GetResolvedAppearanceColor(textStyle, "color")
        or textStyle.color or { 1, 1, 1, 1 }
    arrow:SetVertexColor(unpack(color))
    arrow:Show()
end

local function ApplyTransferLogDirectionArrow(row)
    local nativeArrow = row and row.Arrow
    if not nativeArrow then return end

    local arrow = row.NSkinTransferDirectionArrow
    if not arrow and row.CreateTexture then
        arrow = row:CreateTexture(nil, "ARTWORK", nil, 1)
        arrow:SetAllPoints(nativeArrow)
        arrow:SetTexture(NSkin.mediaPath .. "angle-small-down.png")
        arrow:SetRotation(math.pi / 2)
        NSkin:ConfigureOwnedPixelTexture(arrow)
        row.NSkinTransferDirectionArrow = arrow
    end

    ConcealTexture(nativeArrow)
    if arrow then
        arrow:SetAllPoints(nativeArrow)
        arrow:SetTexture(NSkin.mediaPath .. "angle-small-down.png")
        arrow:SetRotation(math.pi / 2)
        arrow:SetVertexColor(1, 1, 1, 1)
        arrow:Show()
    end
end

function CharacterSkin:ApplyCurrencyTransfer()
    local transfer = _G.CurrencyTransferMenu
    local content = transfer and transfer.Content
    if not transfer or not content then return false end

    ConcealTexture(transfer.Background)
    ConcealTexture(content.TransactionDivider)
    NSkin:ConcealWindowArtwork(transfer.Inset)
    local applied = ApplyAuxiliaryWindowChrome(
        transfer, IDs.CurrencyTransfer.Scope, IDs.CurrencyTransfer.Window,
        IDs.CurrencyTransfer.HeaderControls, "Currency Transfer window")

    local sourceSelector = content.SourceSelector
    local sourceDropdown = sourceSelector and sourceSelector.Dropdown
    local sourceLabel = sourceSelector and sourceSelector.SourceLabel
    local receiverText = sourceSelector and sourceSelector.PlayerName

    local amountSelector = content.AmountSelector
    local amountLabel = amountSelector and amountSelector.TransferAmountLabel
    local amountInput = amountSelector and amountSelector.InputBox
    local maxButton = amountSelector and amountSelector.MaxQuantityButton

    local sourceBalance = content.SourceBalancePreview
    local sourceBalanceInfo = sourceBalance and sourceBalance.BalanceInfo
    local sourceBalanceLabel = sourceBalance and sourceBalance.Label
    local sourceBalanceAmount = sourceBalanceInfo and sourceBalanceInfo.Amount
    local sourceBalanceIcon = sourceBalanceInfo and sourceBalanceInfo.CurrencyIcon

    local playerBalance = content.PlayerBalancePreview
    local playerBalanceInfo = playerBalance and playerBalance.BalanceInfo
    local playerBalanceLabel = playerBalance and playerBalance.Label
    local playerBalanceAmount = playerBalanceInfo and playerBalanceInfo.Amount
    local playerBalanceIcon = playerBalanceInfo and playerBalanceInfo.CurrencyIcon

    local confirmButton = content.ConfirmButton
    local cancelButton = content.CancelButton

    ApplyTransferDirectionArrow(sourceSelector)

    -- Source line:
    -- TEXT label + DROPDOWN + decorative media arrow + TEXT receiver.
    applied = RegisterCurrencyTransferRow({
        id = IDs.CurrencyTransfer.SourceRow,
        label = "Currency transfer source",
        window = transfer,
        target = sourceSelector,
        priority = 70,
        columns = {
            { kind = "TEXT", target = sourceLabel },
            { kind = "TEXT", target = receiverText },
        },
        extraSkins = {
            {
                kind = "DROPDOWN",
                target = sourceDropdown,
                menus = { "MENU_CURRENCY_TRANSFER" },
            },
        },
        members = {
            { kind = "TEXT", role = "SECONDARY",
                target = sourceLabel, label = "Source label" },
            { kind = "DROPDOWN", role = "SECONDARY",
                target = sourceDropdown, label = "Source" },
            { kind = "TEXT", role = "SECONDARY",
                target = receiverText, label = "Receiver" },
        },
        highlightRegions = {
            sourceSelector, sourceDropdown, sourceLabel, receiverText,
        },
    }) or applied

    -- Amount line:
    -- TEXT label + composite operation area (BUTTON Max + EDIT_BOX amount).
    applied = RegisterCurrencyTransferRow({
        id = IDs.CurrencyTransfer.AmountRow,
        label = "Currency transfer amount",
        window = transfer,
        target = amountSelector,
        priority = 71,
        columns = {
            { kind = "TEXT", target = amountLabel },
            {
                kind = "BUTTON",
                target = maxButton,
                skinOptions = {
                    label = maxButton and maxButton:GetText() or "",
                },
            },
        },
        extraSkins = {
            { kind = "EDIT_BOX", target = amountInput },
        },
        members = {
            { kind = "TEXT", role = "SECONDARY",
                target = amountLabel, label = "Label" },
            { kind = "BUTTON", role = "SECONDARY",
                target = maxButton, label = "Maximum" },
            { kind = "EDIT_BOX", role = "SECONDARY",
                target = amountInput, label = "Amount" },
        },
        highlightRegions = {
            amountSelector, amountLabel, maxButton, amountInput,
        },
    }) or applied

    -- Source balance:
    -- TEXT label + amount/icon presentation grouped under the ROW.
    applied = RegisterCurrencyTransferRow({
        id = IDs.CurrencyTransfer.SourceBalanceRow,
        label = "Source currency balance",
        window = transfer,
        target = sourceBalance,
        priority = 72,
        columns = {
            { kind = "TEXT", target = sourceBalanceLabel },
            { kind = "TEXT", target = sourceBalanceAmount },
            {
                kind = "ICON",
                target = sourceBalanceIcon,
                texture = sourceBalanceIcon,
                borderOwner = sourceBalanceInfo,
            },
        },
        members = {
            { kind = "TEXT", role = "SECONDARY",
                target = sourceBalanceLabel, label = "Label" },
            { kind = "TEXT", role = "SECONDARY",
                target = sourceBalanceAmount, label = "Amount" },
            { kind = "ICON", role = "SECONDARY",
                target = sourceBalanceIcon, label = "Currency icon" },
        },
        highlightRegions = {
            sourceBalance, sourceBalanceLabel,
            sourceBalanceAmount, sourceBalanceIcon,
        },
    }) or applied

    -- Player balance:
    -- TEXT label + amount/icon presentation grouped under the ROW.
    applied = RegisterCurrencyTransferRow({
        id = IDs.CurrencyTransfer.PlayerBalanceRow,
        label = "Player currency balance",
        window = transfer,
        target = playerBalance,
        priority = 73,
        columns = {
            { kind = "TEXT", target = playerBalanceLabel },
            { kind = "TEXT", target = playerBalanceAmount },
            {
                kind = "ICON",
                target = playerBalanceIcon,
                texture = playerBalanceIcon,
                borderOwner = playerBalanceInfo,
            },
        },
        members = {
            { kind = "TEXT", role = "SECONDARY",
                target = playerBalanceLabel, label = "Label" },
            { kind = "TEXT", role = "SECONDARY",
                target = playerBalanceAmount, label = "Amount" },
            { kind = "ICON", role = "SECONDARY",
                target = playerBalanceIcon, label = "Currency icon" },
        },
        highlightRegions = {
            playerBalance, playerBalanceLabel,
            playerBalanceAmount, playerBalanceIcon,
        },
    }) or applied

    applied = NSkin:RegisterActionButton({
        id = IDs.CurrencyTransfer.ConfirmButton, module = "Character",
        appearanceWindowID = IDs.CurrencyTransfer.Scope,
        label = "Confirm currency transfer", window = transfer,
        target = confirmButton, priority = 74,
        highlightRegions = { confirmButton },
        isEditable = function()
            return transfer:IsVisible() and confirmButton:IsVisible()
        end,
    }) ~= nil or applied

    applied = RegisterFlatButton(
        IDs.CurrencyTransfer.CancelButton, IDs.CurrencyTransfer.Scope,
        "Cancel currency transfer", transfer, cancelButton, 75) ~= nil or applied

    return applied
end

function CharacterSkin:ApplyCurrencyTransferLogRows()
    local log = _G.CurrencyTransferLog
    local scrollBox = log and log.ScrollBox
    if not log or not scrollBox then return false end

    local function Refresh()
        local resolvedRowStyle = NSkin:GetAppearanceStyle(
            "row", IDs.CurrencyTransferLog.Scope, IDs.CurrencyTransferLog.Rows)
        local rowStyle = {}
        for key, value in pairs(resolvedRowStyle or {}) do
            rowStyle[key] = value
        end
        rowStyle.borderSize = 0
        local rowBorder = NSkin:GetAppearanceBorderColor(
            "row", rowStyle, IDs.CurrencyTransferLog.Scope,
            IDs.CurrencyTransferLog.Rows)
        local applied = false

        NSkin:ForEachScrollBoxFrame(scrollBox, function(row)
            if not IsCurrencyTransferLogRow(row) then return end
            ApplyTransferLogDirectionArrow(row)
            local columns = {
                { kind = "TEXT", target = row.SourceName },
                { kind = "TEXT", target = row.DestinationName },
                { kind = "TEXT", target = row.CurrencyQuantity },
                {
                    kind = "ICON",
                    target = row.CurrencyIcon,
                    texture = row.CurrencyIcon,
                    borderOwner = row,
                },
            }
            local state = NSkin:SkinRow(row, {
                style = rowStyle,
                border = rowBorder,
                showBackground = false,
                nativeDecorationRegions = GetTransferLogNativeDecorations(row),
                getHovered = IsRowHovered,
                columns = columns,
                elementID = IDs.CurrencyTransferLog.Rows,
                appearanceWindowID = IDs.CurrencyTransferLog.Scope,
            })
            if state and state.border then
                NSkin:SetPixelBorderShown(state.border, false)
            end
            applied = state ~= nil or applied
        end)

        NSkin:NotifySkinningElementBoundsChanged(IDs.CurrencyTransferLog.Rows)
        return applied
    end

    if not currencyTransferLogRowsRegistered then
        currencyTransferLogRowsRegistered = NSkin:RegisterSkinningElement(
            IDs.CurrencyTransferLog.Rows, {
                module = "Character",
                appearanceWindowID = IDs.CurrencyTransferLog.Scope,
                label = "Currency transfer log rows",
                kind = "ROW",
                window = log,
                target = scrollBox,
                priority = 72,
                draggable = false,
                appearanceStyles = { "row", "text", "icon" },
                appearanceTypeIDs = { "ROW", "TEXT", "ICON" },
                editorOptions = {
                    { id = "shared.rowAppearance", label = "Row",
                        category = "CUSTOMIZE" },
                    { id = "shared.textAppearance", label = "Text",
                        category = "CUSTOMIZE" },
                    { id = "shared.iconAppearance", label = "Icons",
                        category = "CUSTOMIZE" },
                },
                highlightRegions = function()
                    return GetVisibleScrollBoxRows(
                        scrollBox, IsCurrencyTransferLogRow)
                end,
                pixelBorderTargets = function()
                    return GetVisibleScrollBoxRows(
                        scrollBox, IsCurrencyTransferLogRow)
                end,
                refreshAppearance = Refresh,
                refreshLayout = Refresh,
                isEditable = function()
                    return log:IsVisible()
                        and #GetVisibleScrollBoxRows(
                            scrollBox, IsCurrencyTransferLogRow) > 0
                end,
            }) == true
    end

    HookScrollBoxRefresh(scrollBox, function()
        CharacterSkin:ApplyCurrencyTransferLogRows()
    end)
    return Refresh()
end

function CharacterSkin:ApplyCurrencyTransferLog()
    local log = _G.CurrencyTransferLog
    if not log then return false end

    ConcealTexture(log.Background)
    NSkin:ConcealWindowArtwork(log.Inset)
    local applied = ApplyAuxiliaryWindowChrome(
        log, IDs.CurrencyTransferLog.Scope, IDs.CurrencyTransferLog.Window,
        IDs.CurrencyTransferLog.HeaderControls, "Currency Transfer Log window")

    local emptyMessage = log.EmptyLogMessage
    local scrollBar = log.ScrollBar
    applied = NSkin:RegisterTextElement({
        id = IDs.CurrencyTransferLog.EmptyMessage, module = "Character",
        appearanceWindowID = IDs.CurrencyTransferLog.Scope,
        label = "Currency transfer empty message", window = log,
        target = emptyMessage, priority = 70,
        highlightRegions = { emptyMessage },
        isEditable = function()
            return log:IsVisible() and emptyMessage:IsVisible()
        end,
    }) ~= nil or applied
    applied = NSkin:RegisterScrollBar({
        id = IDs.CurrencyTransferLog.ScrollBar, module = "Character",
        appearanceWindowID = IDs.CurrencyTransferLog.Scope,
        label = "Currency transfer log scroll bar", window = log,
        target = scrollBar, priority = 71,
        highlightRegions = { scrollBar },
        isEditable = function()
            return log:IsVisible() and scrollBar:IsVisible()
        end,
    }) ~= nil or applied
    applied = self:ApplyCurrencyTransferLogRows() or applied
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
    self:ApplyPaperDollSkin(frame)
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
    if not paperDollStatsHooked and _G.hooksecurefunc
        and type(_G.PaperDollFrame_UpdateStats) == "function"
    then
        _G.hooksecurefunc("PaperDollFrame_UpdateStats", function()
            if initialized then
                CharacterSkin:ApplyPaperDollStats(frame)
            end
        end)
        paperDollStatsHooked = true
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
