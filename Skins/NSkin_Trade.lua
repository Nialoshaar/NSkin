local _, NSkin = ...

local TradeSkin = NSkin:NewModule("Trade")

local IDs = {
    Scope = "Trade",
    Window = "Trade.Window",
    HeaderControls = "Trade.HeaderControls",
    PlayerName = "Trade.PlayerName",
    RecipientName = "Trade.RecipientName",
    PlayerItems = "Trade.PlayerItems",
    RecipientItems = "Trade.RecipientItems",
    PlayerEnchant = "Trade.PlayerEnchant",
    RecipientEnchant = "Trade.RecipientEnchant",
    PlayerEnchantLabel = "Trade.PlayerEnchantLabel",
    RecipientEnchantLabel = "Trade.RecipientEnchantLabel",
    PlayerMoney = "Trade.PlayerMoney",
    RecipientMoney = "Trade.RecipientMoney",
    AcceptButton = "Trade.AcceptButton",
    CancelButton = "Trade.CancelButton",
}

local ITEM_GROUP_DEFINITIONS = {
    { id = IDs.PlayerItems, label = "Player trade items",
        side = "Player", indices = { 1, 2, 3, 4, 5, 6 }, priority = 30 },
    { id = IDs.RecipientItems, label = "Recipient trade items",
        side = "Recipient", indices = { 1, 2, 3, 4, 5, 6 }, priority = 31 },
    { id = IDs.PlayerEnchant, label = "Player enchant slot",
        side = "Player", indices = { 7 }, priority = 32 },
    { id = IDs.RecipientEnchant, label = "Recipient enchant slot",
        side = "Recipient", indices = { 7 }, priority = 33 },
}

local initialized = false
local showHooked = false
local eventHooked = false
local groupRegistrations = {}

NSkin:RegisterAppearanceScope(IDs.Scope, {
    label = "Trade",
})

local function IsForbidden(target)
    return target and target.IsForbidden and target:IsForbidden() or false
end

local function IsVisible(target)
    return target and not IsForbidden(target)
        and target.IsVisible and target:IsVisible() or false
end

local function GetButtonTexture(button, method, field)
    if not button then return nil end
    if type(button[method]) == "function" then
        local texture = button[method](button)
        if texture then return texture end
    end
    return button[field]
end

local function IsHovered(target)
    return target and target.IsMouseOver and target:IsMouseOver() or false
end

local function AppendRegion(regions, seen, region)
    if region and not seen[region] then
        seen[region] = true
        regions[#regions + 1] = region
    end
end

local function AppendNineSliceRegions(regions, seen, nineSlice)
    if not nineSlice then return end
    for _, key in ipairs({
        "Center", "TopEdge", "BottomEdge", "LeftEdge", "RightEdge",
        "TopLeftCorner", "TopRightCorner", "BottomLeftCorner",
        "BottomRightCorner",
    }) do
        AppendRegion(regions, seen, nineSlice[key])
    end
end

local function AppendInsetRegions(regions, seen, inset)
    if not inset then return end
    AppendRegion(regions, seen, inset.Bg)
    AppendRegion(regions, seen, inset.Background)
    AppendNineSliceRegions(regions, seen, inset.NineSlice)
end

local function AppendDirectTextureRegions(regions, seen, owner)
    if not owner or not owner.GetRegions then return end
    for _, region in ipairs({ owner:GetRegions() }) do
        if region.IsObjectType and region:IsObjectType("Texture") then
            AppendRegion(regions, seen, region)
        end
    end
end

local function SuppressDecorations(owner, key, regions)
    if not owner then return end
    local data = NSkin:GetSkinData(owner, "tradeDecorations:" .. key)
    data.states = data.states or {}
    for _, region in ipairs(regions or {}) do
        if region then
            local state = data.states[region]
            if not state then
                state = {
                    alpha = region.GetAlpha and region:GetAlpha() or 1,
                    shown = region.IsShown and region:IsShown() or nil,
                }
                data.states[region] = state
            end
            state.active = true
            local function Conceal()
                if not state.active or state.applying then return end
                state.applying = true
                if region.SetAlpha then region:SetAlpha(0) end
                if region.Hide then region:Hide() end
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
end

local function RefreshElement(element)
    if element then NSkin:RefreshTypedElementAppearance(element) end
    return element
end

local function GetTradeItem(side, index)
    return _G["Trade" .. side .. "Item" .. index]
end

local function GetTradeItemButton(side, index, row)
    return _G["Trade" .. side .. "Item" .. index .. "ItemButton"]
        or (row and (row.ItemButton or row.itemButton))
end

local function GetTradeItemTexture(side, index, button)
    local prefix = "Trade" .. side .. "Item" .. index .. "ItemButton"
    return _G[prefix .. "IconTexture"]
        or (button and (button.Icon or button.icon
            or button.IconTexture or button.iconTexture))
end

local function GetTradeItemText(side, index, row)
    return _G["Trade" .. side .. "Item" .. index .. "Name"]
        or (row and (row.Name or row.name))
end

local function GetTradeItemDecorations(side, index, row)
    local prefix = "Trade" .. side .. "Item" .. index
    local button = GetTradeItemButton(side, index, row)
    local buttonPrefix = prefix .. "ItemButton"
    local regions, seen = {}, {}
    AppendRegion(regions, seen, row and row.SlotTexture)
    AppendRegion(regions, seen, _G[prefix .. "SlotTexture"])
    AppendRegion(regions, seen, row and row.NameFrame)
    AppendRegion(regions, seen, _G[prefix .. "NameFrame"])
    AppendRegion(regions, seen, GetButtonTexture(
        button, "GetNormalTexture", "NormalTexture"))
    AppendRegion(regions, seen, _G[buttonPrefix .. "NormalTexture"])
    AppendRegion(regions, seen, GetButtonTexture(
        button, "GetPushedTexture", "PushedTexture"))
    AppendRegion(regions, seen, _G[buttonPrefix .. "PushedTexture"])
    return regions
end

local function GetTradeItemQuality(side, index)
    if side == "Player" and type(_G.GetTradePlayerItemInfo) == "function" then
        return select(4, _G.GetTradePlayerItemInfo(index))
    end
    if side == "Recipient"
        and type(_G.GetTradeTargetItemInfo) == "function"
    then
        return select(4, _G.GetTradeTargetItemInfo(index))
    end
end

local function GetGroupTargets(side, indices, visibleOnly)
    local targets = {}
    for _, index in ipairs(indices) do
        local row = GetTradeItem(side, index)
        local button = GetTradeItemButton(side, index, row)
        local text = GetTradeItemText(side, index, row)
        if button and (not visibleOnly or IsVisible(button)) then
            targets[#targets + 1] = button
        end
        if text and (not visibleOnly or IsVisible(text)) then
            targets[#targets + 1] = text
        end
    end
    return targets
end

local function GetGroupBorderTargets(side, indices, visibleOnly)
    local targets = {}
    for _, index in ipairs(indices) do
        local row = GetTradeItem(side, index)
        local button = GetTradeItemButton(side, index, row)
        if button and (not visibleOnly or IsVisible(button)) then
            targets[#targets + 1] = button
        end
    end
    return targets
end

function TradeSkin:ApplyWindowChrome(frame)
    local regions, seen = {}, {}
    local recipientOverlay = frame.RecipientOverlay
    for _, region in ipairs({
        _G.TradeRecipientBG,
        _G.TradeRecipientBotLeftCorner,
        _G.TradeRecipientLeftBorder,
        recipientOverlay and recipientOverlay.portrait,
        recipientOverlay and recipientOverlay.portraitFrame,
        _G.TradePlayerItem7SlotTexture,
        _G.TradeRecipientItem7SlotTexture,
    }) do
        AppendRegion(regions, seen, region)
    end
    for _, inset in ipairs({
        _G.TradePlayerItemsInset,
        _G.TradeRecipientItemsInset,
        _G.TradePlayerEnchantInset,
        _G.TradeRecipientEnchantInset,
        _G.TradePlayerInputMoneyInset,
        _G.TradeRecipientMoneyInset,
    }) do
        AppendInsetRegions(regions, seen, inset)
    end
    local recipientMoneyBg = _G.TradeRecipientMoneyBg
    AppendRegion(regions, seen, recipientMoneyBg)
    AppendDirectTextureRegions(regions, seen, recipientMoneyBg)
    AppendInsetRegions(regions, seen, recipientMoneyBg)
    AppendNineSliceRegions(regions, seen,
        recipientMoneyBg and recipientMoneyBg.Border)
    SuppressDecorations(frame, "Window", regions)

    NSkin:SkinStandardWindowChrome({
        frame = frame,
        appearanceWindowID = IDs.Scope,
        elementID = IDs.Window,
        headerControlsID = IDs.HeaderControls,
        title = frame.TitleContainer and frame.TitleContainer.TitleText,
        closeButton = frame.CloseButton or _G.TradeFrameCloseButton,
    })
    NSkin:RegisterSkinningElement(IDs.Window, {
        label = "Trade window",
        kind = "WINDOW",
        module = "Trade",
        appearanceWindowID = IDs.Scope,
        window = frame,
        target = frame,
        priority = 0,
        draggable = false,
    })
    return true
end

local function RegisterText(frame, id, label, target, priority)
    if not target then return false end
    local element = NSkin:RegisterTextElement({
        id = id,
        module = "Trade",
        appearanceWindowID = IDs.Scope,
        label = label,
        window = frame,
        target = target,
        priority = priority,
        highlightRegions = { target },
        isEditable = function()
            return IsVisible(frame) and IsVisible(target)
        end,
    })
    return RefreshElement(element) ~= nil
end

function TradeSkin:ApplyTexts(frame)
    local applied = false
    for _, definition in ipairs({
        { IDs.PlayerName, "Player name", _G.TradeFramePlayerNameText, 20 },
        { IDs.RecipientName, "Recipient name",
            _G.TradeFrameRecipientNameText, 21 },
        { IDs.PlayerEnchantLabel, "Player enchant label",
            _G.TradeFramePlayerEnchantText, 22 },
        { IDs.RecipientEnchantLabel, "Recipient enchant label",
            _G.TradeFrameRecipientEnchantText, 23 },
    }) do
        applied = RegisterText(frame, unpack(definition)) or applied
    end
    return applied
end

local function GetItemDescriptors(side, indices)
    local descriptors = {}
    for _, index in ipairs(indices) do
        local row = GetTradeItem(side, index)
        local button = GetTradeItemButton(side, index, row)
        local texture = GetTradeItemTexture(side, index, button)
        if button and texture and not IsForbidden(button)
            and not IsForbidden(texture)
        then
            local itemIndex = index
            descriptors[#descriptors + 1] = {
                target = button,
                texture = texture,
                borderOwner = button,
                nativeDecorationRegions = GetTradeItemDecorations(
                    side, index, row),
                hoverRegion = GetButtonTexture(
                    button, "GetHighlightTexture", "HighlightTexture"),
                getHovered = IsHovered,
                qualityProvider = function()
                    return GetTradeItemQuality(side, itemIndex)
                end,
            }
        end
    end
    return descriptors
end

function TradeSkin:StyleItemGroupContent(side, indices, elementID)
    local textStyle = NSkin:GetAppearanceStyle(
        "text", IDs.Scope, elementID)
    local applied = false
    for _, index in ipairs(indices) do
        local row = GetTradeItem(side, index)
        local text = GetTradeItemText(side, index, row)
        local decorations = GetTradeItemDecorations(side, index, row)
        SuppressDecorations(row, side .. "Item" .. index, decorations)
        if text and not IsForbidden(text) then
            applied = NSkin:SkinText(text, textStyle) == true or applied
        end
    end
    return applied
end

function TradeSkin:ApplyItemGroup(frame, definition)
    local id, label = definition.id, definition.label
    local side, indices = definition.side, definition.indices
    if not groupRegistrations[id] then
        groupRegistrations[id] = NSkin:RegisterIconGroup({
            id = id,
            module = "Trade",
            appearanceWindowID = IDs.Scope,
            label = label,
            window = frame,
            target = GetTradeItem(side, indices[1]),
            priority = definition.priority,
            draggable = false,
            children = function()
                return GetItemDescriptors(side, indices)
            end,
            refreshContent = function()
                return TradeSkin:StyleItemGroupContent(side, indices, id)
            end,
            appearanceStyles = { "text" },
            appearanceTypeIDs = { "TEXT" },
            highlightRegions = function()
                return GetGroupTargets(side, indices, true)
            end,
            pixelBorderTargets = function()
                return GetGroupBorderTargets(side, indices, true)
            end,
            editorOptions = {
                { id = "shared.iconAppearance", label = "Icons",
                    category = "CUSTOMIZE" },
                { id = "shared.textAppearance", label = "Text",
                    category = "CUSTOMIZE" },
            },
            isEditable = function()
                return IsVisible(frame)
                    and #GetGroupTargets(side, indices, true) > 0
            end,
        })
    else
        NSkin:RefreshIconGroup(groupRegistrations[id])
    end
    if groupRegistrations[id] then
        NSkin:NotifySkinningElementBoundsChanged(id)
    end
    return groupRegistrations[id] ~= nil
end

function TradeSkin:ApplyItemGroups(frame)
    local applied = false
    for _, definition in ipairs(ITEM_GROUP_DEFINITIONS) do
        applied = self:ApplyItemGroup(frame, definition) or applied
    end
    return applied
end

local function GetPlayerMoneyInputs(visibleOnly)
    local inputs = {}
    for _, denomination in ipairs({ "Gold", "Silver", "Copper" }) do
        local input = _G["TradePlayerInputMoneyFrame" .. denomination]
        if input and not IsForbidden(input)
            and (not visibleOnly or IsVisible(input))
        then
            inputs[#inputs + 1] = input
        end
    end
    return inputs
end

function TradeSkin:StylePlayerMoney()
    local style = NSkin:GetAppearanceStyle(
        "editBox", IDs.Scope, IDs.PlayerMoney)
    local border = NSkin:GetAppearanceBorderColor(
        "editBox", style, IDs.Scope, IDs.PlayerMoney)
    local applied = false
    for _, input in ipairs(GetPlayerMoneyInputs(false)) do
        NSkin:SkinEditBox(input, { style = style, border = border })
        applied = true
    end
    return applied
end

function TradeSkin:ApplyPlayerMoney(frame)
    local owner = _G.TradePlayerInputMoneyFrame
    local target = not IsForbidden(owner) and owner
        or _G.TradePlayerInputMoneyInset
    if not target then return false end
    local applied = self:StylePlayerMoney()
    if not groupRegistrations[IDs.PlayerMoney] then
        local function RefreshMoney()
            return TradeSkin:StylePlayerMoney()
        end
        groupRegistrations[IDs.PlayerMoney] = NSkin:RegisterSkinningElement(
            IDs.PlayerMoney, {
                module = "Trade",
                appearanceWindowID = IDs.Scope,
                label = "Player trade money input",
                kind = "EDIT_BOX",
                window = frame,
                target = target,
                priority = 40,
                draggable = false,
                highlightRegions = function()
                    return GetPlayerMoneyInputs(true)
                end,
                pixelBorderTargets = function()
                    return GetPlayerMoneyInputs(true)
                end,
                editorOptions = {
                    { id = "shared.editBoxAppearance", label = "Money inputs",
                        presentation = "INLINE", category = "CUSTOMIZE" },
                },
                refreshAppearance = RefreshMoney,
                refreshLayout = RefreshMoney,
                isEditable = function()
                    return IsVisible(frame)
                        and #GetPlayerMoneyInputs(true) > 0
                end,
            }) == true
    end
    return applied or groupRegistrations[IDs.PlayerMoney]
end

local function GetRecipientMoneyTexts(visibleOnly)
    local moneyFrame = _G.TradeRecipientMoneyFrame
    local texts = {}
    for _, denomination in ipairs({ "Gold", "Silver", "Copper" }) do
        local button = moneyFrame and moneyFrame[denomination .. "Button"]
        local text = button and (button.Text or button.text)
            or _G["TradeRecipientMoneyFrame" .. denomination .. "ButtonText"]
        if text and (not visibleOnly or IsVisible(text)) then
            texts[#texts + 1] = {
                target = text,
                numberFormat = string.upper(denomination),
            }
        end
    end
    return texts
end

function TradeSkin:StyleRecipientMoney()
    local style = NSkin:GetAppearanceStyle(
        "text", IDs.Scope, IDs.RecipientMoney)
    local applied = false
    for _, definition in ipairs(GetRecipientMoneyTexts(false)) do
        applied = NSkin:SkinText(definition.target, style, {
            numberFormat = definition.numberFormat,
        }) == true or applied
    end
    return applied
end

function TradeSkin:ApplyRecipientMoney(frame)
    local moneyFrame = _G.TradeRecipientMoneyFrame
    if not moneyFrame then return false end
    local applied = self:StyleRecipientMoney()
    if not groupRegistrations[IDs.RecipientMoney] then
        local function GetVisibleTexts()
            local targets = {}
            for _, definition in ipairs(GetRecipientMoneyTexts(true)) do
                targets[#targets + 1] = definition.target
            end
            return targets
        end
        local function RefreshMoney()
            return TradeSkin:StyleRecipientMoney()
        end
        groupRegistrations[IDs.RecipientMoney] =
            NSkin:RegisterSkinningElement(IDs.RecipientMoney, {
                module = "Trade",
                appearanceWindowID = IDs.Scope,
                label = "Recipient trade money",
                kind = "TEXT",
                window = frame,
                target = moneyFrame,
                priority = 41,
                draggable = false,
                highlightRegions = GetVisibleTexts,
                editorOptions = {
                    { id = "shared.textAppearance", label = "Money text",
                        category = "CUSTOMIZE" },
                },
                refreshAppearance = RefreshMoney,
                refreshLayout = RefreshMoney,
                isEditable = function()
                    return IsVisible(frame) and #GetVisibleTexts() > 0
                end,
            }) == true
    end
    if groupRegistrations[IDs.RecipientMoney] then
        NSkin:NotifySkinningElementBoundsChanged(IDs.RecipientMoney)
    end
    return applied or groupRegistrations[IDs.RecipientMoney]
end

function TradeSkin:ApplyButtons(frame)
    local applied = false
    local acceptButton = _G.TradeFrameTradeButton
    if acceptButton then
        local element = NSkin:RegisterActionButton({
            id = IDs.AcceptButton,
            module = "Trade",
            appearanceWindowID = IDs.Scope,
            label = "Accept trade button",
            window = frame,
            target = acceptButton,
            priority = 50,
            skinOptions = {
                preserveTexture = acceptButton.WarningIcon,
            },
            highlightRegions = { acceptButton },
            isEditable = function()
                return IsVisible(frame) and IsVisible(acceptButton)
            end,
        })
        applied = RefreshElement(element) ~= nil or applied
    end

    local cancelButton = _G.TradeFrameCancelButton
    if cancelButton then
        local element = NSkin:RegisterTypedElement("BUTTON", {
            id = IDs.CancelButton,
            module = "Trade",
            appearanceWindowID = IDs.Scope,
            label = "Cancel trade button",
            window = frame,
            target = cancelButton,
            priority = 51,
            highlightRegions = { cancelButton },
            isEditable = function()
                return IsVisible(frame) and IsVisible(cancelButton)
            end,
        })
        applied = RefreshElement(element) ~= nil or applied
    end
    return applied
end

function TradeSkin:Apply()
    local frame = _G.TradeFrame
    if not frame then return false end
    local applied = self:ApplyWindowChrome(frame)
    applied = self:ApplyTexts(frame) or applied
    applied = self:ApplyItemGroups(frame) or applied
    applied = self:ApplyPlayerMoney(frame) or applied
    applied = self:ApplyRecipientMoney(frame) or applied
    applied = self:ApplyButtons(frame) or applied
    return applied
end

function TradeSkin:Initialize()
    local frame = _G.TradeFrame
    if not frame then return false end
    if not showHooked and frame.HookScript then
        frame:HookScript("OnShow", function()
            TradeSkin:Apply()
        end)
        showHooked = true
    end
    if not eventHooked and frame.HookScript then
        frame:HookScript("OnEvent", function(_, event, index)
            if event == "TRADE_PLAYER_ITEM_CHANGED" then
                TradeSkin:ApplyItemGroup(frame,
                    ITEM_GROUP_DEFINITIONS[index == 7 and 3 or 1])
            elseif event == "TRADE_TARGET_ITEM_CHANGED" then
                TradeSkin:ApplyItemGroup(frame,
                    ITEM_GROUP_DEFINITIONS[index == 7 and 4 or 2])
            elseif event == "TRADE_SHOW" or event == "TRADE_UPDATE" then
                TradeSkin:ApplyItemGroups(frame)
                TradeSkin:ApplyRecipientMoney(frame)
            end
        end)
        eventHooked = true
    end
    initialized = true
    return self:Apply()
end

function TradeSkin:RefreshAppearance()
    if initialized then self:Apply() end
end

NSkin:RegisterWindowSkin({
    key = "Trade.Window",
    module = "Trade",
    addon = "Blizzard_UIPanels_Game",
    apply = function()
        return TradeSkin:Initialize()
    end,
})
