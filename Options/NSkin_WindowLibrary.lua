local _, NSkin = ...
local THEME = NSkin.editorTheme
local menus = NSkin._componentOptionMenus
local skins = { { value = "BLIZZARD_MODERN", label = "Blizzard Modern" },
    { value = "NSKIN", label = "NSkin" } }
local categories = { "All windows", "Character", "Inventory", "Adventure", "Social", "System" }
local categoryByModule = {
    Character = "Character", SpellBook = "Character", Collections = "Character",
    Professions = "Character", Achievements = "Character", Transmogrification = "Character",
    BarberShop = "Character", Stable = "Character", CooldownManager = "Character",
    Storage = "Inventory", Mailbox = "Inventory", Trade = "Inventory",
    ItemUpgrade = "Inventory", TradingPost = "Inventory", Shop = "Inventory", AuctionHouse = "Inventory",
    EncounterJournal = "Adventure", Map = "Adventure", GroupFinder = "Adventure",
    GreatVault = "Adventure", Delves = "Adventure", ExpansionFeatures = "Adventure",
    HousingDashboard = "Social", FriendsList = "Social", Communities = "Social", Calendar = "Social",
}
local function Category(info) return categoryByModule[info.module] or "System" end
local function Label(parent, text, size, color)
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    label:SetFont(GameFontNormal:GetFont(), size or 13, "")
    label:SetTextColor(unpack(color or THEME.text))
    label:SetJustifyH("LEFT")
    label:SetText(text)
    return label
end
local function Button(parent, text, width, callback)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(width, 28)
    NSkin:SkinFlatButton(button, text, THEME.input, THEME.border, 12)
    button:SetScript("OnClick", callback)
    return button
end
local function Dropdown(parent, width)
    local dropdown = menus.CreateOwnedDropdown(parent)
    dropdown:SetSize(width, 28)
    menus.SkinAddonDropdown(dropdown)
    local background = NSkin:GetFlatBackground(dropdown, "NSkinOptionsDropdown")
    if background then NSkin:SetOwnedTextureColor(background, unpack(THEME.input)) end
    NSkin:SetPixelBorderColor(NSkin:GetPixelBorder(dropdown, "NSkinOptionsDropdownBorder"), unpack(THEME.border))
    if dropdown.text then dropdown.text:SetTextColor(unpack(THEME.text)) end
    return dropdown
end
local function Checkbox(parent)
    local checkbox = NSkin:CreateOwnedOptionsCheckbox(parent)
    if checkbox.Text then checkbox.Text:SetText("") end
    return checkbox
end

function NSkin:BuildWindowsLibrary(parent, entries)
    local page = self:CreateOptionsPage(parent)
    local category, status, skinFilter, pageIndex = "All windows", "ALL", "ALL", 1
    local selected, filtered, rows, tabs = {}, {}, {}, {}
    local pageSize, pageCount = 12, 1
    local title = Label(page, "Windows", 22)
    title:SetPoint("TOPLEFT")
    local badge = CreateFrame("Frame", nil, page)
    badge:SetSize(68, 24)
    badge:SetPoint("TOPRIGHT")
    NSkin:CreateFlatBackground(badge, nil, THEME.input, THEME.border)
    local badgeLabel = Label(badge, "LIBRARY", 10, THEME.accent)
    badgeLabel:SetPoint("CENTER")
    local description = Label(page, "Manage window skins. Changes require a UI reload.", 13, THEME.muted)
    description:SetPoint("TOPLEFT", 0, -34)
    local totals = Label(page, "", 13)
    totals:SetPoint("TOPLEFT", 0, -66)
    local matches = Label(page, "", 12, THEME.muted)
    local selectionHint = Label(page, "Select rows to make changes in bulk", 11, THEME.muted)
    local search = CreateFrame("EditBox", nil, page)
    search:SetHeight(28)
    search:SetAutoFocus(false)
    search:SetFont(GameFontNormal:GetFont(), 12, "")
    search:SetTextColor(unpack(THEME.text))
    search:SetTextInsets(10, 10, 0, 0)
    NSkin:CreateFlatBackground(search, nil, THEME.input, THEME.border)
    local placeholder = Label(search, "Find a window...", 12, THEME.muted)
    placeholder:SetPoint("LEFT", 10, 0)
    local statusPicker, skinPicker = Dropdown(page, 112), Dropdown(page, 140)
    local bulk = CreateFrame("Frame", nil, page)
    bulk:SetHeight(28)
    local selectionLabel = Label(bulk, "", 12, THEME.accent)
    selectionLabel:SetPoint("LEFT")
    local function Changed()
        page:Refresh()
        if page.onModuleConfigurationChanged then page.onModuleConfigurationChanged() end
    end
    local function ApplySelected(enabled, skin)
        local owners = {}
        for _, info in ipairs(entries) do
            if selected[info.key] and not owners[info.module] then
                owners[info.module] = true
                if skin then NSkin:SetModuleSkin(info.module, skin)
                else NSkin:SetModuleEnabled(info.module, enabled) end
            end
        end
        if next(owners) then Changed() end
    end
    local enable = Button(bulk, "Enable", 62, function() ApplySelected(true) end)
    local disable = Button(bulk, "Disable", 68, function() ApplySelected(false) end)
    local bulkSkin = Dropdown(bulk, 140)
    bulkSkin:SetPoint("RIGHT")
    disable:SetPoint("RIGHT", bulkSkin, "LEFT", -8, 0)
    enable:SetPoint("RIGHT", disable, "LEFT", -8, 0)
    bulkSkin:SetDefaultText("Set selected skin")
    bulkSkin:SetupMenu(function(_, root)
        for _, choice in ipairs(skins) do
            local value = choice.value
            root:CreateButton(choice.label, function() ApplySelected(nil, value) end)
        end
    end)
    local tableFrame = CreateFrame("Frame", nil, page)
    NSkin:CreateFlatBackground(tableFrame, nil, THEME.input, THEME.border)
    local header = CreateFrame("Frame", nil, tableFrame)
    header:SetHeight(32)
    header:SetPoint("TOPLEFT", 1, -1)
    header:SetPoint("TOPRIGHT", -1, -1)
    local selectAll = Checkbox(header)
    selectAll:SetPoint("LEFT", 2, 0)
    local windowHeading = Label(header, "WINDOW", 10, THEME.muted)
    windowHeading:SetPoint("LEFT", 44, 0)
    local categoryHeading = Label(header, "CATEGORY", 10, THEME.muted)
    local enabledHeading = Label(header, "ENABLED", 10, THEME.muted)
    enabledHeading:SetPoint("RIGHT", -170, 0)
    local skinHeading = Label(header, "SKIN", 10, THEME.muted)
    skinHeading:SetPoint("RIGHT", -118, 0)
    NSkin:CreateEditorDivider(header, header, false, -32)
    local empty = Label(tableFrame, "No matching windows.", 13, THEME.muted)
    empty:SetPoint("TOPLEFT", 16, -48)
    local rangeLabel = Label(page, "", 12, THEME.muted)
    local pageLabel = Label(page, "", 12, THEME.muted)
    local previous = Button(page, "<", 30, function()
        pageIndex = math.max(1, pageIndex - 1); page:Refresh()
    end)
    local following = Button(page, ">", 30, function()
        pageIndex = math.min(pageCount, pageIndex + 1); page:Refresh()
    end)
    local note = Label(page, "Disabled windows keep their selected skin.", 12, THEME.muted)
    local function FilterChanged() pageIndex = 1; page:Refresh() end
    statusPicker:SetupMenu(function(_, root)
        for _, choice in ipairs({ { "ALL", "All statuses" }, { "ENABLED", "Enabled" }, { "DISABLED", "Disabled" } }) do
            local value = choice[1]
            root:CreateRadio(choice[2], function() return status == value end,
                function() status = value; FilterChanged() end)
        end
    end)
    skinPicker:SetupMenu(function(_, root)
        root:CreateRadio("All skins", function() return skinFilter == "ALL" end,
            function() skinFilter = "ALL"; FilterChanged() end)
        for _, choice in ipairs(skins) do
            local value = choice.value
            root:CreateRadio(choice.label, function() return skinFilter == value end,
                function() skinFilter = value; FilterChanged() end)
        end
    end)
    for _, name in ipairs(categories) do
        local value = name
        local tab = Button(page, name, 98, function() category = value; FilterChanged() end)
        tab.category = name
        tabs[#tabs + 1] = tab
    end
    for i = 1, 12 do
        local row = CreateFrame("Frame", nil, tableFrame)
        row:SetHeight(40)
        row.background = row:CreateTexture(nil, "BACKGROUND")
        row.background:SetAllPoints()
        row.background:SetColorTexture(unpack(i % 2 == 0 and THEME.input or THEME.panel))
        NSkin:ConfigureOwnedPixelTexture(row.background)
        row.select = Checkbox(row)
        row.select:SetPoint("LEFT", 2, 0)
        row.select:SetScript("OnClick", function(self)
            if row.info then selected[row.info.key] = self:GetChecked() == true or nil; page:Refresh() end
        end)
        row.name = CreateFrame("Button", nil, row)
        row.name:SetPoint("LEFT", 44, 0)
        row.name:SetHeight(30)
        row.label = Label(row.name, "", 13)
        row.label:SetPoint("LEFT")
        row.label:SetPoint("RIGHT")
        row.name:SetScript("OnClick", function()
            if row.info and row.info.builder and page.openWindowSettings then page.openWindowSettings(row.info.key) end
        end)
        row.category = Label(row, "", 11, THEME.muted)
        row.enable = Checkbox(row)
        row.enable:SetPoint("RIGHT", -177, 0)
        row.enable:SetScript("OnClick", function(self)
            if row.info then NSkin:SetModuleEnabled(row.info.module, self:GetChecked() == true); Changed() end
        end)
        row.picker = Dropdown(row, 140)
        row.picker:SetPoint("RIGHT", -12, 0)
        row.picker:SetupMenu(function(_, root)
            local info = row.info
            if not info then return end
            for _, choice in ipairs(skins) do
                local value = choice.value
                root:CreateRadio(choice.label, function() return NSkin:GetModuleSkin(info.module) == value end,
                    function() if NSkin:SetModuleSkin(info.module, value) then Changed() end end)
            end
        end)
        NSkin:CreateEditorDivider(row, row, false, -40)
        rows[#rows + 1] = row
    end
    selectAll:SetScript("OnClick", function(self)
        for _, row in ipairs(rows) do
            if row.info then selected[row.info.key] = self:GetChecked() == true or nil end
        end
        page:Refresh()
    end)
    function page:Refresh()
        if self.layingOut then return end
        self.layingOut = true
        local width = math.max(1, self:GetWidth())
        local enabledCount, counts, selectionCount = 0, {}, 0
        local query = (search:GetText() or ""):lower():match("^%s*(.-)%s*$")
        filtered = {}
        for _, info in ipairs(entries) do
            local enabled = NSkin:GetModuleEnabledPreference(info.module)
            if enabled then enabledCount = enabledCount + 1 end
            local group = Category(info)
            counts[group] = (counts[group] or 0) + 1
            if selected[info.key] then selectionCount = selectionCount + 1 end
            if (category == "All windows" or category == group)
                and (status == "ALL" or enabled == (status == "ENABLED"))
                and (skinFilter == "ALL" or NSkin:GetModuleSkin(info.module) == skinFilter)
                and (query == "" or info.label:lower():find(query, 1, true)) then
                filtered[#filtered + 1] = info
            end
        end
        totals:SetText(#entries .. " windows     " .. enabledCount .. " enabled     " .. (#entries - enabledCount) .. " disabled")
        local tabColumns = math.max(1, math.min(6, math.floor((width + 8) / 106)))
        for i, tab in ipairs(tabs) do
            tab:ClearAllPoints()
            tab:SetPoint("TOPLEFT", ((i - 1) % tabColumns) * 106, -92 - math.floor((i - 1) / tabColumns) * 36)
            NSkin:SkinFlatButton(tab, tab.category .. " " .. (tab.category == "All windows" and #entries or (counts[tab.category] or 0)),
                tab.category == category and THEME.selected or THEME.input, THEME.border, 11)
        end
        local filtersY = 92 + math.ceil(#tabs / tabColumns) * 36 + 8
        local narrow = width < 620
        search:ClearAllPoints(); search:SetPoint("TOPLEFT", 0, -filtersY)
        search:SetWidth(narrow and width or width - 268)
        statusPicker:ClearAllPoints(); skinPicker:ClearAllPoints()
        if narrow then statusPicker:SetPoint("TOPRIGHT", page, "TOPRIGHT", -148, -filtersY - 36)
        else statusPicker:SetPoint("TOPLEFT", search, "TOPRIGHT", 8, 0) end
        skinPicker:SetPoint("TOPRIGHT", page, "TOPRIGHT", 0, -filtersY - (narrow and 36 or 0))
        statusPicker:SetDefaultText(status == "ALL" and "All statuses" or (status == "ENABLED" and "Enabled" or "Disabled"))
        skinPicker:SetDefaultText(skinFilter == "ALL" and "All skins" or (skinFilter == "NSKIN" and "NSkin" or "Blizzard Modern"))
        local matchesY = filtersY + (narrow and 76 or 40)
        matches:ClearAllPoints(); matches:SetPoint("TOPLEFT", 0, -matchesY)
        matches:SetText(#filtered .. " matching windows")
        selectionHint:ClearAllPoints(); selectionHint:SetPoint("TOPRIGHT", 0, -matchesY)
        selectionHint:SetShown(selectionCount == 0)
        bulk:ClearAllPoints(); bulk:SetPoint("TOPLEFT", 0, -matchesY - 24); bulk:SetWidth(width)
        bulk:SetShown(selectionCount > 0); selectionLabel:SetText(selectionCount .. " selected")
        local tableY = matchesY + (selectionCount > 0 and 60 or 28)
        local viewport = parent:GetParent()
        local available = viewport and viewport:GetHeight() or 720
        pageSize = math.max(3, math.min(12, math.floor((available - tableY - 104) / 40)))
        pageCount = math.max(1, math.ceil(#filtered / pageSize))
        pageIndex = math.max(1, math.min(pageIndex, pageCount))
        tableFrame:ClearAllPoints(); tableFrame:SetPoint("TOPLEFT", 0, -tableY); tableFrame:SetWidth(width)
        local first = (pageIndex - 1) * pageSize + 1
        local shown = math.max(0, math.min(pageSize, #filtered - first + 1))
        tableFrame:SetHeight(34 + math.max(1, shown) * 40)
        categoryHeading:ClearAllPoints(); categoryHeading:SetPoint("LEFT", width * .49, 0); categoryHeading:SetShown(not narrow)
        local allSelected = shown > 0
        for i, row in ipairs(rows) do
            local info = i <= shown and filtered[first + i - 1] or nil
            row.info = info; row:SetShown(info ~= nil)
            if info then
                row:ClearAllPoints(); row:SetPoint("TOPLEFT", 1, -33 - (i - 1) * 40); row:SetWidth(width - 2)
                row.name:SetWidth(narrow and width - 254 or width * .49 - 58)
                row.label:SetText(info.label .. (info.builder and " >" or ""))
                row.category:ClearAllPoints(); row.category:SetPoint("LEFT", width * .49, 0); row.category:SetShown(not narrow)
                row.category:SetText(Category(info))
                row.select:SetChecked(selected[info.key] == true)
                if not selected[info.key] then allSelected = false end
                row.enable:SetChecked(NSkin:GetModuleEnabledPreference(info.module))
                row.picker:SetDefaultText(NSkin:GetModuleSkin(info.module) == "NSKIN" and "NSkin" or "Blizzard Modern")
            end
        end
        selectAll:SetChecked(allSelected); empty:SetShown(shown == 0)
        local footerY = tableY + tableFrame:GetHeight() + 12
        rangeLabel:ClearAllPoints(); rangeLabel:SetPoint("TOPLEFT", 0, -footerY - 8)
        rangeLabel:SetText((shown > 0 and first or 0) .. "-" .. (first + shown - 1) .. " of " .. #filtered .. " windows")
        following:ClearAllPoints(); following:SetPoint("TOPRIGHT", 0, -footerY)
        pageLabel:ClearAllPoints(); pageLabel:SetPoint("RIGHT", following, "LEFT", -12, 0)
        pageLabel:SetText("Page " .. pageIndex .. " of " .. pageCount)
        previous:ClearAllPoints(); previous:SetPoint("RIGHT", pageLabel, "LEFT", -12, 0)
        previous:SetEnabled(pageIndex > 1); following:SetEnabled(pageIndex < pageCount)
        note:ClearAllPoints(); note:SetPoint("TOPLEFT", 0, -footerY - 42)
        self:SetContentHeight(footerY + 64)
        self.layingOut = nil
    end
    page.ApplyAppearance = page.Refresh
    search:SetScript("OnEscapePressed", function(self) self:SetText(""); self:ClearFocus() end)
    search:SetScript("OnTextChanged", function(self)
        placeholder:SetShown((self:GetText() or "") == ""); FilterChanged()
    end)
    page:SetScript("OnSizeChanged", function() page:Refresh() end)
    page:Refresh()
    return page
end
