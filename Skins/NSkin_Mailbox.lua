local _, NSkin = ...

local MailboxSkin = NSkin:NewModule("Mailbox")

local IDs = {
    Scope = "Mailbox",
    Window = "Mailbox.Window",
    HeaderControls = "Mailbox.HeaderControls",
    OpenAllMail = "Mailbox.OpenAllMail",
    Pagination = {
        Group = "Mailbox.Inbox.Pagination",
        Previous = "Mailbox.Inbox.Pagination.Previous",
        Next = "Mailbox.Inbox.Pagination.Next",
        Text = "Mailbox.Inbox.Pagination.Text",
    },
    Tabs = "Mailbox.Tabs",
    RowPrefix = "Mailbox.Inbox.Row",
    OpenMail = {
        Scope = "Mailbox.OpenMail",
        Window = "Mailbox.OpenMail.Window",
        HeaderControls = "Mailbox.OpenMail.HeaderControls",
        ScrollBar = "Mailbox.OpenMail.ScrollBar",
        Sender = "Mailbox.OpenMail.Sender",
        SenderLabel = "Mailbox.OpenMail.SenderLabel",
        Subject = "Mailbox.OpenMail.Subject",
        SubjectLabel = "Mailbox.OpenMail.SubjectLabel",
        AttachmentText = "Mailbox.OpenMail.AttachmentText",
        ReplyButton = "Mailbox.OpenMail.ReplyButton",
        DeleteButton = "Mailbox.OpenMail.DeleteButton",
        CancelButton = "Mailbox.OpenMail.CancelButton",
        AttachmentPrefix = "Mailbox.OpenMail.Attachment",
    },
    SendMail = {
        Scope = "Mailbox.SendMail",
        Window = "Mailbox.SendMail.Window",
        HeaderControls = "Mailbox.SendMail.HeaderControls",
        NameInput = "Mailbox.SendMail.NameInput",
        NameLabel = "Mailbox.SendMail.NameLabel",
        SubjectInput = "Mailbox.SendMail.SubjectInput",
        SubjectLabel = "Mailbox.SendMail.SubjectLabel",
        CostLabel = "Mailbox.SendMail.CostLabel",
        CostCopper = "Mailbox.SendMail.CostCopper",
        MoneyGold = "Mailbox.SendMail.MoneyGold",
        MoneySilver = "Mailbox.SendMail.MoneySilver",
        MoneyCopper = "Mailbox.SendMail.MoneyCopper",
        ScrollBar = "Mailbox.SendMail.ScrollBar",
        InputGold = "Mailbox.SendMail.InputGold",
        InputSilver = "Mailbox.SendMail.InputSilver",
        InputCopper = "Mailbox.SendMail.InputCopper",
        SendMoneyRadio = "Mailbox.SendMail.SendMoneyRadio",
        CODRadio = "Mailbox.SendMail.CODRadio",
        SendButton = "Mailbox.SendMail.SendButton",
        CancelButton = "Mailbox.SendMail.CancelButton",
        AttachmentPrefix = "Mailbox.SendMail.Attachment",
    },
}

local initialized = false
local showHooked = false
local inboxUpdateHooked = false
local openMailShowHooked = false
local sendMailShowHooked = false
local tabsRegistered = false
local paginationController
local hookedTabs = setmetatable({}, { __mode = "k" })

NSkin:RegisterAppearanceScope(IDs.Scope, {
    label = "Mailbox",
})
NSkin:RegisterAppearanceScope(IDs.OpenMail.Scope, {
    label = "Open Mail",
    parent = IDs.Scope,
})
NSkin:RegisterAppearanceScope(IDs.SendMail.Scope, {
    label = "Send Mail",
    parent = IDs.Scope,
})

local function IsVisible(target)
    return target and target.IsVisible and target:IsVisible() or false
end

local function RefreshElement(element)
    if element then NSkin:RefreshTypedElementAppearance(element) end
    return element
end

local function GetTextureRegions(frame)
    local regions = {}
    if not frame or not frame.GetRegions then return regions end
    for _, region in ipairs({ frame:GetRegions() }) do
        if region and region.GetObjectType
            and region:GetObjectType() == "Texture"
        then
            regions[#regions + 1] = region
        end
    end
    return regions
end

local function GetButtonStateTexture(button, method, field)
    if not button then return nil end
    if type(button[method]) == "function" then
        local texture = button[method](button)
        if texture then return texture end
    end
    return button[field]
end

local function FindFontStringByText(owner, expectedText)
    if not owner or not owner.GetRegions then return nil end
    for _, region in ipairs({ owner:GetRegions() }) do
        if region and region.GetObjectType
            and region:GetObjectType() == "FontString"
            and region.GetText and region:GetText() == expectedText
        then
            return region
        end
    end
end

local function GetIconTexture(button, globalName)
    if not button then return nil end
    return button.Icon or button.icon or button.IconTexture
        or button.iconTexture or _G[globalName .. "IconTexture"]
        or (button.GetNormalTexture and button:GetNormalTexture())
end

local function GetIconDecorations(button, texture)
    if not button then return {} end
    local preserved = {}
    local function Preserve(region)
        if region then preserved[region] = true end
    end
    Preserve(texture)
    Preserve(GetButtonStateTexture(button, "GetHighlightTexture",
        "HighlightTexture"))
    Preserve(GetButtonStateTexture(button, "GetCheckedTexture",
        "CheckedTexture"))
    Preserve(GetButtonStateTexture(button, "GetPushedTexture",
        "PushedTexture"))
    Preserve(button.IconOverlay)
    Preserve(button.IconOverlay2)
    Preserve(button.ProfessionQualityOverlay)
    local regions = {}
    for _, region in ipairs(GetTextureRegions(button)) do
        if not preserved[region] then regions[#regions + 1] = region end
    end
    return regions
end


local function SuppressDecorations(owner, key, regions)
    if not owner then return end
    local data = NSkin:GetSkinData(owner, "mailboxDecorations")
    data[key] = data[key] or { states = {} }
    local group = data[key]
    for _, region in ipairs(regions or {}) do
        if region then
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
end

function MailboxSkin:ApplyWindowChrome(frame)
    NSkin:SkinStandardWindowChrome({
        frame = frame,
        appearanceWindowID = IDs.Scope,
        elementID = IDs.Window,
        headerControlsID = IDs.HeaderControls,
    })
    NSkin:RegisterSkinningElement(IDs.Window, {
        label = "Mailbox window",
        kind = "WINDOW",
        module = "Mailbox",
        appearanceWindowID = IDs.Scope,
        window = frame,
        target = frame,
        priority = 0,
        draggable = false,
    })
    return true
end

function MailboxSkin:ApplyOpenAllButton(frame)
    local button = _G.OpenAllMail
    if not button then return false end
    return RefreshElement(NSkin:RegisterTypedElement("BUTTON", {
        id = IDs.OpenAllMail,
        module = "Mailbox",
        appearanceWindowID = IDs.Scope,
        label = "Open all mail button",
        window = frame,
        target = button,
        priority = 40,
        isEditable = function()
            return IsVisible(frame) and IsVisible(button)
        end,
    })) ~= nil
end

function MailboxSkin:ApplyPagination(frame)
    local inbox = _G.InboxFrame
    local previous = _G.InboxPrevPageButton
    local nextPage = _G.InboxNextPageButton
    local pageText = _G.InboxCurrentPage
    if not inbox or not previous or not nextPage or not pageText then
        return false
    end

    inbox.PrevPageButton = previous
    inbox.NextPageButton = nextPage
    inbox.PageText = pageText
    NSkin:SkinPagingControls(inbox)

    if not paginationController then
        paginationController = NSkin:RegisterPaginationGroup({
            module = "Mailbox",
            appearanceWindowID = IDs.Scope,
            window = frame,
            ids = {
                group = IDs.Pagination.Group,
                previous = IDs.Pagination.Previous,
                next = IDs.Pagination.Next,
                text = IDs.Pagination.Text,
            },
            controls = {
                group = inbox,
                previous = previous,
                next = nextPage,
                text = pageText,
            },
            groupLabel = "Inbox pagination",
            previousLabel = "Inbox previous page button",
            nextLabel = "Inbox next page button",
            textLabel = "Inbox page text",
            groupPriority = 41,
            buttonPriority = 42,
            textPriority = 43,
            visibilityFrame = inbox,
            elements = {
                group = { draggable = false },
            },
        })
    else
        paginationController:Refresh()
    end
    return paginationController ~= nil
end

function MailboxSkin:ApplyTabs(frame)
    local tabs = { _G.MailFrameTab1, _G.MailFrameTab2 }
    if not tabs[1] or not tabs[2] then return false end

    local style = NSkin:GetAppearanceStyle("tab", IDs.Scope, IDs.Tabs)
    local border = NSkin:GetAppearanceBorderColor(
        "tab", style, IDs.Scope, IDs.Tabs)
    local selected = _G.PanelTemplates_GetSelectedTab
        and _G.PanelTemplates_GetSelectedTab(frame)
    for index, tab in ipairs(tabs) do
        NSkin:SkinTab(tab, index == selected, style, border)
        if not hookedTabs[tab] and tab.HookScript then
            tab:HookScript("OnClick", function()
                MailboxSkin:ApplyTabs(frame)
            end)
            hookedTabs[tab] = true
        end
    end

    if not tabsRegistered then
        tabsRegistered = NSkin:RegisterTabGroup(IDs.Tabs, {
            label = "Mailbox bottom tabs",
            kind = "TAB_GROUP",
            module = "Mailbox",
            appearanceWindowID = IDs.Scope,
            window = frame,
            tabs = tabs,
            priority = 50,
            orientation = "HORIZONTAL",
            edge = "BOTTOM",
        }) ~= nil
    end
    return true
end

function MailboxSkin:ApplyRows(frame)
    local inbox = _G.InboxFrame
    if not inbox then return false end

    local applied = false
    for index = 1, 7 do
        local globalPrefix = "MailItem" .. index
        local row = _G[globalPrefix]
        local button = _G[globalPrefix .. "Button"]
        local sender = _G[globalPrefix .. "Sender"]
        local subject = _G[globalPrefix .. "Subject"]
        local expireButton = _G[globalPrefix .. "ExpireTime"]
        local expireText = expireButton and expireButton.GetFontString
            and expireButton:GetFontString()
        local rowID = IDs.RowPrefix .. index

        if row then
            applied = RefreshElement(NSkin:RegisterRow({
                id = rowID,
                module = "Mailbox",
                appearanceWindowID = IDs.Scope,
                label = "Inbox mail row " .. index,
                window = frame,
                target = row,
                nativeDecorationRegions = GetTextureRegions(row),
                priority = 60 + index,
                isEditable = function()
                    return IsVisible(frame) and IsVisible(inbox)
                        and IsVisible(row)
                end,
            })) ~= nil or applied
        end

        if button and button.Icon then
            local nativeDecorations = {}
            for _, region in ipairs({
                _G[globalPrefix .. "ButtonSlot"],
                button.IconBorder,
                _G[globalPrefix .. "ButtonIconBorder"],
            }) do
                if region then nativeDecorations[#nativeDecorations + 1] = region end
            end
            local element = NSkin:RegisterIcon({
                id = rowID .. ".Icon",
                module = "Mailbox",
                appearanceWindowID = IDs.Scope,
                label = "Inbox mail row " .. index .. " icon",
                window = frame,
                target = button,
                texture = button.Icon,
                borderOwner = button,
                nativeDecorationRegions = nativeDecorations,
                hoverRegion = GetButtonStateTexture(
                    button, "GetHighlightTexture", "HighlightTexture"),
                selectedRegion = GetButtonStateTexture(
                    button, "GetCheckedTexture", "CheckedTexture"),
                getHovered = function(target)
                    return target and target.IsMouseOver
                        and target:IsMouseOver() or false
                end,
                getSelected = function(target)
                    return target and target.GetChecked
                        and target:GetChecked() == true or false
                end,
                priority = 70 + index,
                isEditable = function()
                    return IsVisible(frame) and IsVisible(inbox)
                        and IsVisible(button)
                end,
            })
            applied = RefreshElement(element) ~= nil or applied
        end

        for textIndex, definition in ipairs({
            { "Sender", "sender", sender },
            { "Subject", "subject", subject },
            { "ExpireTime", "expiration time", expireText },
        }) do
            local suffix, label, target = unpack(definition)
            if target then
                local element = NSkin:RegisterTextElement({
                    id = rowID .. "." .. suffix,
                    module = "Mailbox",
                    appearanceWindowID = IDs.Scope,
                    label = "Inbox mail row " .. index .. " " .. label,
                    window = frame,
                    target = target,
                    priority = 80 + (index * 3) + textIndex,
                    highlightRegions = { target },
                    isEditable = function()
                        return IsVisible(frame) and IsVisible(inbox)
                            and IsVisible(target)
                    end,
                })
                applied = RefreshElement(element) ~= nil or applied
            end
        end
    end
    return applied
end

function MailboxSkin:ApplyOpenMailWindowChrome(frame)
    NSkin:SkinStandardWindowChrome({
        frame = frame,
        appearanceWindowID = IDs.OpenMail.Scope,
        elementID = IDs.OpenMail.Window,
        headerControlsID = IDs.OpenMail.HeaderControls,
    })
    NSkin:RegisterSkinningElement(IDs.OpenMail.Window, {
        label = "Open mail window",
        kind = "WINDOW",
        module = "Mailbox",
        appearanceWindowID = IDs.OpenMail.Scope,
        window = frame,
        target = frame,
        priority = 0,
        draggable = false,
    })
    return true
end

function MailboxSkin:ApplyOpenMailText(frame)
    local senderFrame = _G.OpenMailSender
    local applied = false
    for index, definition in ipairs({
        { IDs.OpenMail.Sender, "Open mail sender",
            senderFrame and senderFrame.Name or senderFrame },
        { IDs.OpenMail.SenderLabel, "Open mail sender label",
            _G.OpenMailSenderLabel },
        { IDs.OpenMail.Subject, "Open mail subject", _G.OpenMailSubject },
        { IDs.OpenMail.SubjectLabel, "Open mail subject label",
            _G.OpenMailSubjectLabel },
        { IDs.OpenMail.AttachmentText, "Open mail attachment text",
            _G.OpenMailAttachmentText },
    }) do
        local id, label, target = unpack(definition)
        if target and target.SetTextColor then
            local element = NSkin:RegisterTextElement({
                id = id,
                module = "Mailbox",
                appearanceWindowID = IDs.OpenMail.Scope,
                label = label,
                window = frame,
                target = target,
                priority = 20 + index,
                highlightRegions = { target },
                isEditable = function()
                    return IsVisible(frame) and IsVisible(target)
                end,
            })
            applied = RefreshElement(element) ~= nil or applied
        end
    end
    return applied
end

function MailboxSkin:ApplyOpenMailScrollBar(frame)
    local scrollFrame = _G.OpenMailScrollFrame
    local scrollBar = scrollFrame and (scrollFrame.ScrollBar
        or scrollFrame.scrollBar) or _G.OpenMailScrollFrameScrollBar
    if not scrollBar then return false end
    return RefreshElement(NSkin:RegisterScrollBar({
        id = IDs.OpenMail.ScrollBar,
        module = "Mailbox",
        appearanceWindowID = IDs.OpenMail.Scope,
        label = "Open mail scroll bar",
        window = frame,
        target = scrollBar,
        priority = 30,
        highlightRegions = { scrollBar },
        isEditable = function()
            return IsVisible(frame) and IsVisible(scrollBar)
        end,
    })) ~= nil
end

function MailboxSkin:ApplyOpenMailButtons(frame)
    local applied = false
    for index, definition in ipairs({
        { IDs.OpenMail.ReplyButton, "Open mail reply button",
            _G.OpenMailReplyButton },
        { IDs.OpenMail.DeleteButton, "Open mail delete button",
            _G.OpenMailDeleteButton },
        { IDs.OpenMail.CancelButton, "Open mail cancel button",
            _G.OpenMailCancelButton },
    }) do
        local id, label, button = unpack(definition)
        if button then
            local element = NSkin:RegisterTypedElement("BUTTON", {
                id = id,
                module = "Mailbox",
                appearanceWindowID = IDs.OpenMail.Scope,
                label = label,
                window = frame,
                target = button,
                priority = 40 + index,
                isEditable = function()
                    return IsVisible(frame) and IsVisible(button)
                end,
            })
            applied = RefreshElement(element) ~= nil or applied
        end
    end
    return applied
end

function MailboxSkin:ApplyOpenMailAttachments(frame)
    local applied = false
    for index = 1, 16 do
        local buttonName = "OpenMailAttachmentButton" .. index
        local button = _G[buttonName]
        local texture = button and (button.Icon or button.icon
            or button.IconTexture or button.iconTexture
            or _G[buttonName .. "IconTexture"])
        if button and texture then
            local nativeDecorations = {}
            for _, region in ipairs({
                button.IconBorder,
                button.iconBorder,
                button.SlotBackground,
                button.slotBackground,
                button.GetNormalTexture and button:GetNormalTexture(),
            }) do
                if region and region ~= texture then
                    nativeDecorations[#nativeDecorations + 1] = region
                end
            end
            local element = NSkin:RegisterIcon({
                id = IDs.OpenMail.AttachmentPrefix .. index,
                module = "Mailbox",
                appearanceWindowID = IDs.OpenMail.Scope,
                label = "Open mail attachment " .. index,
                window = frame,
                target = button,
                texture = texture,
                borderOwner = button,
                nativeDecorationRegions = nativeDecorations,
                hoverRegion = GetButtonStateTexture(
                    button, "GetHighlightTexture", "HighlightTexture"),
                getHovered = function(target)
                    return target and target.IsMouseOver
                        and target:IsMouseOver() or false
                end,
                priority = 60 + index,
                isEditable = function()
                    return IsVisible(frame) and IsVisible(button)
                end,
            })
            applied = RefreshElement(element) ~= nil or applied
        end
    end
    return applied
end

function MailboxSkin:ApplyOpenMail()
    local frame = _G.OpenMailFrame
    if not frame then return false end
    local applied = self:ApplyOpenMailWindowChrome(frame)
    applied = self:ApplyOpenMailText(frame) or applied
    applied = self:ApplyOpenMailScrollBar(frame) or applied
    applied = self:ApplyOpenMailButtons(frame) or applied
    applied = self:ApplyOpenMailAttachments(frame) or applied
    return applied
end

function MailboxSkin:ApplySendMailWindowChrome(frame)
    NSkin:SkinStandardWindowChrome({
        frame = frame,
        appearanceWindowID = IDs.SendMail.Scope,
        elementID = IDs.SendMail.Window,
        headerControlsID = IDs.SendMail.HeaderControls,
        skinCloseButton = false,
    })
    NSkin:RegisterSkinningElement(IDs.SendMail.Window, {
        label = "Send mail window",
        kind = "WINDOW",
        module = "Mailbox",
        appearanceWindowID = IDs.SendMail.Scope,
        window = frame,
        target = frame,
        priority = 0,
        draggable = false,
    })
    return true
end

function MailboxSkin:ApplySendMailAddressFields(frame)
    local applied = false
    for index, definition in ipairs({
        { IDs.SendMail.NameInput, IDs.SendMail.NameLabel,
            "Recipient", _G.SendMailNameEditBox, _G.MAIL_TO_LABEL },
        { IDs.SendMail.SubjectInput, IDs.SendMail.SubjectLabel,
            "Subject", _G.SendMailSubjectEditBox, _G.MAIL_SUBJECT_LABEL },
    }) do
        local inputID, textID, label, editBox, labelText = unpack(definition)
        if editBox then
            local element = NSkin:RegisterEditBox({
                id = inputID,
                module = "Mailbox",
                appearanceWindowID = IDs.SendMail.Scope,
                label = "Send mail " .. string.lower(label) .. " input",
                window = frame,
                target = editBox,
                priority = 20 + index,
                highlightRegions = { editBox },
                isEditable = function()
                    return IsVisible(frame) and IsVisible(editBox)
                end,
            })
            applied = RefreshElement(element) ~= nil or applied

            local text = FindFontStringByText(editBox, labelText)
            if text then
                element = NSkin:RegisterTextElement({
                    id = textID,
                    module = "Mailbox",
                    appearanceWindowID = IDs.SendMail.Scope,
                    label = "Send mail " .. string.lower(label) .. " label",
                    window = frame,
                    target = text,
                    priority = 23 + index,
                    highlightRegions = { text },
                    isEditable = function()
                        return IsVisible(frame) and IsVisible(text)
                    end,
                })
                applied = RefreshElement(element) ~= nil or applied
            end
        end
    end
    return applied
end

function MailboxSkin:ApplySendMailMoneyText(frame)
    local costFrame = _G.SendMailCostMoneyFrame
    local applied = false
    for index, definition in ipairs({
        { IDs.SendMail.CostLabel, "Send mail cost label",
            FindFontStringByText(costFrame, _G.SEND_MAIL_COST) },
        { IDs.SendMail.CostCopper, "Send mail cost copper",
            _G.SendMailCostMoneyFrameCopperButtonText },
        { IDs.SendMail.MoneyGold, "Send mail enclosed gold",
            _G.SendMailMoneyFrameGoldButtonText },
        { IDs.SendMail.MoneySilver, "Send mail enclosed silver",
            _G.SendMailMoneyFrameSilverButtonText },
        { IDs.SendMail.MoneyCopper, "Send mail enclosed copper",
            _G.SendMailMoneyFrameCopperButtonText },
    }) do
        local id, label, text = unpack(definition)
        if text then
            local element = NSkin:RegisterTextElement({
                id = id,
                module = "Mailbox",
                appearanceWindowID = IDs.SendMail.Scope,
                label = label,
                window = frame,
                target = text,
                priority = 30 + index,
                highlightRegions = { text },
                isEditable = function()
                    return IsVisible(frame) and IsVisible(text)
                end,
            })
            applied = RefreshElement(element) ~= nil or applied
        end
    end
    return applied
end

function MailboxSkin:ApplySendMailScrollBar(frame)
    local scrollFrame = _G.SendMailScrollFrame
    local scrollBar = scrollFrame and (scrollFrame.ScrollBar
        or scrollFrame.scrollBar) or _G.SendMailScrollFrameScrollBar
    if not scrollBar then return false end
    return RefreshElement(NSkin:RegisterScrollBar({
        id = IDs.SendMail.ScrollBar,
        module = "Mailbox",
        appearanceWindowID = IDs.SendMail.Scope,
        label = "Send mail scroll bar",
        window = frame,
        target = scrollBar,
        priority = 40,
        highlightRegions = { scrollBar },
        isEditable = function()
            return IsVisible(frame) and IsVisible(scrollBar)
        end,
    })) ~= nil
end

function MailboxSkin:ApplySendMailMoneyInputs(frame)
    local applied = false
    for index, definition in ipairs({
        { IDs.SendMail.InputGold, "Send mail gold input",
            _G.SendMailMoneyGold },
        { IDs.SendMail.InputSilver, "Send mail silver input",
            _G.SendMailMoneySilver },
        { IDs.SendMail.InputCopper, "Send mail copper input",
            _G.SendMailMoneyCopper },
    }) do
        local id, label, editBox = unpack(definition)
        if editBox then
            local element = NSkin:RegisterEditBox({
                id = id,
                module = "Mailbox",
                appearanceWindowID = IDs.SendMail.Scope,
                label = label,
                window = frame,
                target = editBox,
                priority = 50 + index,
                highlightRegions = { editBox },
                isEditable = function()
                    return IsVisible(frame) and IsVisible(editBox)
                end,
            })
            applied = RefreshElement(element) ~= nil or applied
        end
    end
    return applied
end

function MailboxSkin:ApplySendMailRadioButtons(frame)
    local applied = false
    for index, definition in ipairs({
        { IDs.SendMail.SendMoneyRadio, "Send money radio button",
            _G.SendMailSendMoneyButton, _G.SendMailSendMoneyButtonText },
        { IDs.SendMail.CODRadio, "Cash on delivery radio button",
            _G.SendMailCODButton, _G.SendMailCODButtonText },
    }) do
        local id, label, button, text = unpack(definition)
        if button then
            local element = NSkin:RegisterCheckbox({
                id = id,
                module = "Mailbox",
                appearanceWindowID = IDs.SendMail.Scope,
                label = label,
                window = frame,
                target = button,
                text = text,
                getChecked = function(target)
                    return target and target.GetChecked
                        and target:GetChecked() == true or false
                end,
                priority = 60 + index,
                highlightRegions = { button, text },
                isEditable = function()
                    return IsVisible(frame) and IsVisible(button)
                end,
            })
            applied = RefreshElement(element) ~= nil or applied
        end
    end
    return applied
end

function MailboxSkin:ApplySendMailButtons(frame)
    local applied = false
    for index, definition in ipairs({
        { IDs.SendMail.SendButton, "Send mail button", _G.SendMailMailButton },
        { IDs.SendMail.CancelButton, "Send mail cancel button",
            _G.SendMailCancelButton },
    }) do
        local id, label, button = unpack(definition)
        if button then
            local element = NSkin:RegisterTypedElement("BUTTON", {
                id = id,
                module = "Mailbox",
                appearanceWindowID = IDs.SendMail.Scope,
                label = label,
                window = frame,
                target = button,
                priority = 70 + index,
                isEditable = function()
                    return IsVisible(frame) and IsVisible(button)
                end,
            })
            applied = RefreshElement(element) ~= nil or applied
        end
    end
    return applied
end

function MailboxSkin:ApplySendMailBackground(frame)
    local background = _G.SendStationeryBackgroundLeft
    if not background then return false end
    SuppressDecorations(frame, "StationeryBackground", { background })
    return true
end

function MailboxSkin:ApplySendMailAttachments(frame)
    local applied = false
    local count = tonumber(_G.ATTACHMENTS_MAX_SEND) or 12
    for index = 1, count do
        local globalName = "SendMailAttachment" .. index
        local button = _G[globalName]
        local texture = GetIconTexture(button, globalName)
        if button and texture then
            local element = NSkin:RegisterIcon({
                id = IDs.SendMail.AttachmentPrefix .. index,
                module = "Mailbox",
                appearanceWindowID = IDs.SendMail.Scope,
                label = "Send mail attachment " .. index,
                window = frame,
                target = button,
                texture = texture,
                borderOwner = button,
                nativeDecorationRegions = GetIconDecorations(button, texture),
                hoverRegion = GetButtonStateTexture(
                    button, "GetHighlightTexture", "HighlightTexture"),
                getHovered = function(target)
                    return target and target.IsMouseOver
                        and target:IsMouseOver() or false
                end,
                priority = 80 + index,
                isEditable = function()
                    return IsVisible(frame) and IsVisible(button)
                end,
            })
            applied = RefreshElement(element) ~= nil or applied
        end
    end
    return applied
end

function MailboxSkin:ApplySendMail()
    local frame = _G.SendMailFrame
    if not frame then return false end
    local applied = self:ApplySendMailWindowChrome(frame)
    applied = self:ApplySendMailAddressFields(frame) or applied
    applied = self:ApplySendMailMoneyText(frame) or applied
    applied = self:ApplySendMailScrollBar(frame) or applied
    applied = self:ApplySendMailMoneyInputs(frame) or applied
    applied = self:ApplySendMailRadioButtons(frame) or applied
    applied = self:ApplySendMailButtons(frame) or applied
    applied = self:ApplySendMailBackground(frame) or applied
    applied = self:ApplySendMailAttachments(frame) or applied
    return applied
end

function MailboxSkin:RefreshInbox()
    local frame = _G.MailFrame
    if not frame then return false end
    local applied = self:ApplyPagination(frame)
    applied = self:ApplyRows(frame) or applied
    return applied
end

function MailboxSkin:Apply()
    local frame = _G.MailFrame
    if not frame then return false end
    local applied = self:ApplyWindowChrome(frame)
    applied = self:ApplyOpenAllButton(frame) or applied
    applied = self:ApplyPagination(frame) or applied
    applied = self:ApplyTabs(frame) or applied
    applied = self:ApplyRows(frame) or applied
    applied = self:ApplyOpenMail() or applied
    applied = self:ApplySendMail() or applied
    return applied
end

function MailboxSkin:Initialize()
    local frame = _G.MailFrame
    if not frame then return false end

    if not showHooked and frame.HookScript then
        frame:HookScript("OnShow", function()
            MailboxSkin:Apply()
        end)
        showHooked = true
    end
    local openMailFrame = _G.OpenMailFrame
    if not openMailShowHooked and openMailFrame and openMailFrame.HookScript then
        openMailFrame:HookScript("OnShow", function()
            MailboxSkin:ApplyOpenMail()
        end)
        openMailShowHooked = true
    end
    local sendMailFrame = _G.SendMailFrame
    if not sendMailShowHooked and sendMailFrame and sendMailFrame.HookScript then
        sendMailFrame:HookScript("OnShow", function()
            MailboxSkin:ApplySendMail()
        end)
        sendMailShowHooked = true
    end
    if not inboxUpdateHooked and type(_G.InboxFrame_Update) == "function"
        and _G.hooksecurefunc
    then
        _G.hooksecurefunc("InboxFrame_Update", function()
            MailboxSkin:RefreshInbox()
        end)
        inboxUpdateHooked = true
    end

    initialized = true
    return self:Apply()
end

function MailboxSkin:RefreshAppearance()
    if initialized then self:Apply() end
end

NSkin:RegisterWindowSkin({
    module = "Mailbox",
    addon = "Blizzard_MailFrame",
    apply = function() return MailboxSkin:Initialize() end,
})
