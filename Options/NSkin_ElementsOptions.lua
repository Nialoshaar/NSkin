local _, NSkin = ...
local THEME = NSkin.editorTheme

-- Existing appearance identities and schemas remain the source of truth.
local elementDefinitions = {
    { kind = "TEXT", label = "Text", style = "typography", group = "appearance.typography",
        category = "Information", description = "Global font, text size, and outline." },
    { kind = "WINDOW", label = "Windows", style = "window", group = "appearance.window",
        category = "Containers", description = "Window surfaces, borders, and backgrounds." },
    { kind = "BUTTON", label = "Buttons", style = "button", group = "appearance.button",
        category = "Controls", description = "Actions, button surfaces, and hover feedback." },
    { kind = "CHECKBOX", label = "Checkboxes", style = "button", group = "appearance.checkbox",
        category = "Controls", description = "Checkbox shape, size, and checkmark. Surfaces inherit Buttons." },
    { kind = "DROPDOWN", label = "Dropdowns", style = "button", group = "appearance.button",
        category = "Controls", description = "Selection menus. Share the canonical Buttons appearance." },
    { kind = "TAB", label = "Tabs", style = "tab", group = "appearance.tab",
        category = "Controls", description = "Navigation tabs and selected states." },
    { kind = "CARD", label = "Cards", style = "sectionCard", group = "appearance.sectionCard",
        category = "Containers", description = "Card surfaces and selection feedback." },
    { kind = "ROW", label = "Rows", style = "sectionRow", group = "appearance.sectionRow",
        category = "Containers", description = "List rows and their selected appearance." },
    { kind = "SEARCH_BOX", label = "Search boxes", style = "searchBox", group = "appearance.search",
        category = "Controls", description = "Search field surfaces and borders." },
    { kind = "SCROLLBAR", label = "Scrollbars", style = "scrollBar", group = "appearance.scrollBar",
        category = "Controls", description = "Scrollbar tracks, thumbs, arrows, and their states." },
    { kind = "ICON", label = "Icons", style = "icon", group = "appearance.icon",
        category = "Information", description = "Icon surfaces, borders, and hover feedback." },
}

local function Label(parent, text, size, color)
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    label:SetFont(GameFontNormal:GetFont(), size or 13, "")
    label:SetTextColor(unpack(color or THEME.text))
    label:SetJustifyH("LEFT")
    label:SetText(text)
    return label
end

local function Surface(frame, color)
    NSkin:CreateFlatBackground(frame, nil, color or THEME.input, THEME.border)
end

local function Action(parent, text, width, callback)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(width, 28)
    NSkin:SkinFlatButton(button, text, THEME.input, THEME.border, 12)
    button:SetScript("OnClick", callback)
    return button
end

-- Preview controls are owned, passive samples rendered by canonical components.
-- They never register Blizzard targets or consume the library card's clicks.
local function CreatePreview(parent, element)
    local preview = CreateFrame("Frame", nil, parent)
    preview:SetSize(160, element.kind == "SCROLLBAR" and 138 or 56)
    local kind = element.kind
    local function Sample(frameType, text)
        local sample = CreateFrame(frameType or "Button", nil, preview)
        sample:EnableMouse(false)
        sample:SetPoint("CENTER")
        if text then
            sample.Text = Label(sample, text, 14)
            sample.Text:SetPoint("CENTER")
            if sample.SetFontString then sample:SetFontString(sample.Text) end
        end
        return sample
    end
    if kind == "TEXT" or kind == "WINDOW" then
        preview.text = Label(preview, kind == "TEXT" and "Your next adventure" or element.label, 14)
        preview.text:SetPoint("CENTER")
    elseif kind == "SCROLLBAR" then
        preview.control = Sample("Frame")
        local bar = preview.control
        bar:SetSize(20, 128)
        bar.Track = CreateFrame("Frame", nil, bar)
        bar.Track:SetPoint("TOP", 0, -18)
        bar.Track:SetPoint("BOTTOM", 0, 18)
        bar.Track:SetWidth(20)
        bar.Track.Thumb = CreateFrame("Frame", nil, bar.Track)
        bar.Track.Thumb:SetSize(20, 30)
        bar.Track.Thumb:SetPoint("CENTER")
        bar.Back = CreateFrame("Button", nil, bar)
        bar.Back:SetSize(14, 14)
        bar.Back:SetPoint("TOP")
        bar.Back:EnableMouse(false)
        bar.Back:Disable()
        bar.Forward = CreateFrame("Button", nil, bar)
        bar.Forward:SetSize(14, 14)
        bar.Forward:SetPoint("BOTTOM")
        bar.Forward:EnableMouse(false)
    elseif kind == "CHECKBOX" then
        preview.control = Sample("CheckButton")
        preview.control:SetChecked(true)
    elseif kind == "SEARCH_BOX" then
        preview.control = Sample("EditBox")
        preview.control:SetAutoFocus(false)
        preview.control:EnableKeyboard(false)
        preview.control:SetFontObject(GameFontHighlight)
        preview.control:SetTextInsets(10, 10, 0, 0)
        preview.control:SetText("Search dungeons...")
    elseif kind == "ICON" then
        preview.control = Sample("Button")
        preview.control.Icon = preview.control:CreateTexture(nil, "ARTWORK")
        preview.control.Icon:SetAllPoints()
        preview.control.Icon:SetTexture(NSkin.mediaPath .. "Logo.png", "CLAMP", "CLAMP", "LINEAR")
    elseif kind == "TAB" then
        preview.tabs = { Sample("Button", "Active"), Sample("Button", "Tab") }
    else
        preview.control = Sample("Button", kind == "DROPDOWN" and "Choose a dungeon"
            or kind == "CARD" and "Premade group" or kind == "ROW" and "Dungeon name" or "Find Group")
    end
    function preview:Refresh()
        if self.refreshing then return end
        self.refreshing = true
        local style = NSkin:GetStyle(element.style)
        local width = math.max(24, math.min(200, self:GetWidth() - 8))
        if kind == "WINDOW" then
            -- Window preview intentionally retains its existing presentation.
            Surface(self, style.background or THEME.input)
            NSkin:SetPixelBorderColor(NSkin:GetPixelBorder(self, "NSkinFlatBackgroundBorder"),
                unpack(style.border or THEME.border))
            self.text:SetTextColor(unpack(style.text or THEME.text))
        elseif kind == "TEXT" then
            local textStyle = NSkin:GetStyle("text")
            NSkin:ApplyResolvedTypography(self.text, textStyle)
            NSkin:SetFontStringColor(self.text, unpack(NSkin:GetResolvedAppearanceColor(textStyle, "color")))
        elseif kind == "SCROLLBAR" then
            NSkin:SkinScrollBar(self.control, style)
        elseif kind == "CHECKBOX" then
            local size = style.checkboxSize or 14
            self.control:SetSize(size, size)
            NSkin:SkinCheckButton(self.control, { style = style })
        elseif kind == "ICON" then
            self.control:SetSize(40, 40)
            NSkin:SkinIcon(self.control, { style = style, texture = self.control.Icon })
        elseif kind == "TAB" then
            for index, tab in ipairs(self.tabs) do
                tab:ClearAllPoints()
                tab:SetSize(math.max(24, (width - 8) / 2), 28)
                tab:SetPoint("CENTER", self, "CENTER", (index == 1 and -1 or 1) * (width + 8) / 4, 0)
                NSkin:SkinTab(tab, index == 1, style)
            end
        else
            self.control:SetSize(width, 32)
            if kind == "DROPDOWN" then
                NSkin:SkinDropdown(self.control, { style = style, preserveText = true })
            elseif kind == "SEARCH_BOX" then
                NSkin:SkinSearchBox(self.control, style)
            elseif kind == "CARD" then
                NSkin:SkinSectionCard(self.control, { style = style, textRegion = self.control.Text,
                    getSelected = function() return false end, getHovered = function() return false end })
            elseif kind == "ROW" then
                NSkin:SkinSectionRow(self.control, { style = style, textRegion = self.control.Text,
                    getSelected = function() return false end, getHovered = function() return false end })
            else
                NSkin:SkinActionButton(self.control, { style = style, label = "Find Group",
                    textRegion = self.control.Text })
            end
        end
        self.refreshing = nil
    end
    preview:Refresh()
    preview:SetScript("OnSizeChanged", function(self) self:Refresh() end)
    return preview
end

local function BuildElementsOptions(parent)
    local registered = {}
    for _, kind in ipairs(NSkin:GetPVEFrameElementTypes()) do registered[kind] = true end
    local elements = {}
    for _, element in ipairs(elementDefinitions) do
        if registered[element.kind] then elements[#elements + 1] = element end
    end
    NSkin:RegisterGlobalAppearanceOptionGroup("appearance.checkbox",
        { "shared.checkboxAppearance" }, {
            shape = "button.checkboxShape", size = "button.checkboxSize",
            checked = "button.checked", checkedMode = "button.checkedMode",
            checkedInset = "button.checkboxCheckedInset",
        }, "Checkboxes")
    local scrollMapping = {}
    for _, key in ipairs({ "track", "trackMode", "trackSize", "trackOpacity",
        "thumb", "thumbMode", "thumbSize", "thumbOpacity", "thumbOffsetX", "thumbOffsetY",
        "arrow", "arrowMode", "arrowOpacity", "arrowDisabled", "arrowDisabledMode",
        "arrowDisabledOpacity", "arrowEnabled", "arrowEnabledMode", "arrowEnabledOpacity" }) do
        scrollMapping[key] = "scrollBar." .. key
    end
    NSkin:RegisterGlobalAppearanceOptionGroup("appearance.scrollBar", {
        "shared.scrollBarBar", "shared.scrollBarThumb", "shared.scrollBarArrowAll",
        "shared.scrollBarArrowDisabled", "shared.scrollBarArrowEnabled",
    }, scrollMapping, "Scrollbars")
    local page = NSkin:CreateOptionsPage(parent)
    local library = CreateFrame("Frame", nil, page)
    library:SetAllPoints()
    local detail = CreateFrame("Frame", nil, page)
    detail.optionsTheme = page.optionsTheme
    detail:SetAllPoints()
    detail:Hide()

    local title = Label(library, "Elements", 22)
    title:SetPoint("TOPLEFT")
    local introduction = Label(library, "Element types registered in Dungeons & Raids (PVEFrame). Settings are shared defaults.", 13, THEME.muted)
    introduction:SetPoint("TOPLEFT", 0, -34)

    local search = CreateFrame("EditBox", nil, library)
    search:SetSize(190, 28)
    search:SetPoint("TOPRIGHT", 0, -68)
    search:SetAutoFocus(false)
    search:SetFont(GameFontNormal:GetFont(), 12, "")
    search:SetTextColor(unpack(THEME.text))
    search:SetTextInsets(10, 10, 0, 0)
    Surface(search)
    search.placeholder = Label(search, "Search elements...", 12, THEME.muted)
    search.placeholder:SetPoint("LEFT", 10, 0)
    search:SetScript("OnEscapePressed", function(self) self:SetText(""); self:ClearFocus() end)

    local filters, cards, views = {}, {}, {}
    local category = "All elements"
    local selected
    local detailTitle = Label(detail, "", 22)
    detailTitle:SetPoint("TOPLEFT")
    local detailDescription = Label(detail, "", 13, THEME.muted)
    detailDescription:SetPoint("TOPLEFT", 0, -34)
    detailDescription:SetPoint("TOPRIGHT", 0, -34)
    local back = Action(detail, "< Back to element library", 184, function() page:ShowLibrary() end)
    back:SetPoint("TOPLEFT", 0, -72)

    local picker = NSkin._componentOptionMenus.CreateOwnedDropdown(detail)
    picker:SetSize(170, 28)
    picker:SetPoint("TOPRIGHT", 0, -72)
    NSkin._componentOptionMenus.SkinAddonDropdown(picker)
    picker:SetupMenu(function(_, root)
        for i = 1, #elements do
            local index = i
            root:CreateRadio(elements[i].label, function() return selected == index end,
                function() page:ShowElement(index) end)
        end
    end)

    local settingsTitle = Label(detail, "Appearance", 14)
    settingsTitle:SetPoint("TOPLEFT", 0, -126)
    local previewPanel = CreateFrame("Frame", nil, detail)
    Surface(previewPanel)
    local previewHeading = Label(previewPanel, "Preview", 12, THEME.muted)
    previewHeading:SetPoint("TOPLEFT", 14, -14)
    local previews = {}
    local previewNote = Label(previewPanel, "Changes apply in real time.", 12, THEME.muted)
    previewNote:SetPoint("BOTTOMLEFT", 14, 14)
    previewNote:SetPoint("BOTTOMRIGHT", -14, 14)

    function page:Layout()
        local width = math.max(1, self:GetWidth())
        if selected then
            local view = views[selected]
            local stacked = width < 640
            local settingsHeight = view:GetHeight()
            previewPanel:ClearAllPoints()
            if stacked then
                previewPanel:SetPoint("TOPLEFT", 0, -176 - settingsHeight)
                previewPanel:SetSize(math.min(width, 400), 190)
                self:SetContentHeight(390 + settingsHeight)
            else
                previewPanel:SetPoint("TOPLEFT", 424, -126)
                previewPanel:SetSize(width - 424, 230)
                self:SetContentHeight(math.max(380, 176 + settingsHeight))
            end
            previews[selected]:SetWidth(math.max(60, math.min(200, previewPanel:GetWidth() - 44)))
        else
            local columns = width >= 690 and 3 or (width >= 430 and 2 or 1)
            local gap = NSkin:SnapToPhysicalPixel(self, 14)
            local cardWidth = (width - (columns - 1) * gap) / columns
            local originX, originY = self:GetLeft() or 0, self:GetTop() or 0
            local function SnapX(value)
                return NSkin:SnapToPhysicalPixel(self, originX + value) - originX
            end
            local function SnapY(value)
                return NSkin:SnapToPhysicalPixel(self, originY + value) - originY
            end
            local visible = 0
            local query = (search:GetText() or ""):lower()
            for i, card in ipairs(cards) do
                local element = elements[i]
                local show = (category == "All elements" or element.category == category)
                    and (query == "" or (element.label .. " " .. element.description):lower():find(query, 1, true) ~= nil)
                card:SetShown(show)
                if show then
                    card:ClearAllPoints()
                    local column = visible % columns
                    local x = SnapX(column * (cardWidth + gap))
                    local right = SnapX(column * (cardWidth + gap) + cardWidth)
                    card:SetPoint("TOPLEFT", x, SnapY(
                        -156 - math.floor(visible / columns) * 184))
                    card:SetSize(right - x, NSkin:SnapToPhysicalPixel(self, 170))
                    card.preview:SetWidth(NSkin:SnapToPhysicalPixel(self,
                        card.vertical and 64 or math.max(60, right - x - 44)))
                    visible = visible + 1
                end
            end
            self.empty:SetShown(visible == 0)
            self:SetContentHeight(170 + math.max(1, math.ceil(visible / columns)) * 184)
        end
    end

    function page:ShowLibrary()
        selected = nil
        library:Show()
        detail:Hide()
        self.navigationSuffix = nil
        self:Layout()
        if self.onNavigationChanged then self.onNavigationChanged() end
    end

    function page:ShowElement(index)
        local element = elements[index]
        if not element then return end
        selected = index
        for _, view in pairs(views) do view:Hide() end
        for _, preview in pairs(previews) do preview:Hide() end
        if not views[index] then
            views[index] = NSkin:CreateOptionGroupView(detail, element.group, "FULL", page)
            views[index]:SetPoint("TOPLEFT", 0, -158)
            previews[index] = CreatePreview(previewPanel, element)
            previews[index]:SetPoint("CENTER", 0, 4)
        end
        views[index]:Show()
        views[index]:Refresh()
        previews[index]:Show()
        previews[index]:Refresh()
        detailTitle:SetText(element.label)
        detailDescription:SetText(element.description)
        picker:SetDefaultText(element.label)
        library:Hide()
        detail:Show()
        self.navigationSuffix = "  /  " .. element.label
        self:Layout()
        if self.onNavigationChanged then self.onNavigationChanged() end
    end

    for i, name in ipairs({ "All elements", "Controls", "Containers", "Information" }) do
        local filterName = name
        local button = Action(library, name, 100, function()
            category = filterName
            for _, filter in ipairs(filters) do
                NSkin:SkinFlatButton(filter, filter.filterName,
                    filter.filterName == category and THEME.selected or THEME.input, THEME.border, 12)
            end
            page:Layout()
        end)
        button.filterName = name
        button:SetPoint("TOPLEFT", (i - 1) * 108, -110)
        filters[#filters + 1] = button
    end
    NSkin:SkinFlatButton(filters[1], "All elements", THEME.selected, THEME.border, 12)

    for i, element in ipairs(elements) do
        local index = i
        local card = CreateFrame("Button", nil, library)
        card.vertical = element.kind == "SCROLLBAR"
        Surface(card)
        card.preview = CreatePreview(card, element)
        if card.vertical then
            card.preview:SetPoint("TOPLEFT", 10, -14)
            NSkin:CreateEditorDivider(card, card, true, 84)
        else
            card.preview:SetPoint("TOP", 0, -14)
            NSkin:CreateEditorDivider(card, card, false, -84)
        end
        local name = Label(card, element.label .. "  >", 14)
        name:SetPoint("TOPLEFT", card.vertical and 100 or 12, card.vertical and -22 or -96)
        local description = Label(card, element.description, 11, THEME.muted)
        description:SetPoint("TOPLEFT", card.vertical and 100 or 12, card.vertical and -52 or -120)
        description:SetPoint("TOPRIGHT", -12, card.vertical and -52 or -120)
        description:SetJustifyV("TOP")
        local tag = Label(card, element.category, 10, THEME.accent)
        tag:SetPoint("BOTTOMLEFT", card.vertical and 100 or 12, 10)
        card:SetScript("OnClick", function() page:ShowElement(index) end)
        cards[#cards + 1] = card
    end
    page.empty = Label(library, "No matching elements.", 13, THEME.muted)
    page.empty:SetPoint("TOPLEFT", 0, -156)
    page.empty:Hide()
    search:SetScript("OnTextChanged", function(self)
        self.placeholder:SetShown((self:GetText() or "") == "")
        page:Layout()
    end)
    page:SetScript("OnSizeChanged", function() page:Layout() end)

    function page:ApplyAppearance()
        for _, card in ipairs(cards) do card.preview:Refresh() end
        if selected then
            views[selected]:ApplyAppearance()
            previews[selected]:Refresh()
        end
    end
    function page:Refresh()
        if selected then views[selected]:Refresh() end
        self:ApplyAppearance()
    end
    page:ShowLibrary()
    return page
end

NSkin:RegisterOptionsPage({ key = "appearance", label = "Elements", group = "shared",
    order = 1, builder = BuildElementsOptions })
