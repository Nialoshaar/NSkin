local _, NSkin = ...

local Clamp = NSkin._componentOptionInternals.Clamp
local DROPDOWN_MENU_MAX_HEIGHT = 300
local DROPDOWN_MENU_SCROLL_THRESHOLD = 12
local OWNED_DROPDOWN_ROW_HEIGHT = 24
local OWNED_DROPDOWN_ROW_STEP = OWNED_DROPDOWN_ROW_HEIGHT - 1
local DROPDOWN_MENU_SKIN = "optionsDropdownMenu"
local DROPDOWN_ARROW_TEXTURE =
    "Interface\\AddOns\\NSkin\\Media\\angle-small-down.png"
local SkinAddonDropdownMenu

local function ConfigureDropdownMenuScroll(rootDescription, choices)
    if not rootDescription or not rootDescription.SetScrollMode then return end
    local entries = 0
    for i = 1, #(choices or {}) do
        if not choices[i].divider and not choices[i].title then
            entries = entries + 1
        end
    end
    if entries > DROPDOWN_MENU_SCROLL_THRESHOLD then
        rootDescription:SetScrollMode(DROPDOWN_MENU_MAX_HEIGHT)
    end
end

local function DropdownChoiceMatches(choice, filter)
    if not filter or filter == "" then return true end
    if choice.divider or choice.title then return false end
    return tostring(choice.label or ""):lower():find(filter, 1, true) ~= nil
end

local function PositionDropdownSearchBox(dropdown, menu, focus)
    local searchBox = dropdown and dropdown.nskinMenuSearchBox
    if not searchBox or not menu then return end
    local data = NSkin:GetSkinData(menu, DROPDOWN_MENU_SKIN)
    if not data.searchInsetAdjusted and menu.ScrollBox then
        data.searchInsetAdjusted = true
        local scrollBox = menu.ScrollBox
        local _, _, _, left, top = scrollBox:GetPoint(1)
        local _, _, _, right, bottom = scrollBox:GetPoint(2)
        scrollBox:ClearAllPoints()
        scrollBox:SetPoint("TOPLEFT", menu, "TOPLEFT", left or 0,
            (top or 0) - 28)
        scrollBox:SetPoint("BOTTOMRIGHT", menu, "BOTTOMRIGHT", right or 0,
            bottom or 0)
        if menu.ScrollBar and menu.ScrollBar:IsShown() then
            menu.ScrollBar:ClearAllPoints()
            menu.ScrollBar:SetPoint("TOPRIGHT", menu, "TOPRIGHT", -1,
                (top or 0) - 28)
            menu.ScrollBar:SetPoint("BOTTOMRIGHT", menu, "BOTTOMRIGHT", -1,
                bottom or 0)
        end
    end
    searchBox:ClearAllPoints()
    searchBox:SetPoint("TOPLEFT", menu, "TOPLEFT", 1, -1)
    searchBox:SetPoint("TOPRIGHT", menu, "TOPRIGHT", -1, -1)
    searchBox:SetHeight(28)
    searchBox:SetFrameStrata(menu:GetFrameStrata())
    searchBox:SetFrameLevel(menu:GetFrameLevel() + 1000)
    searchBox:Show()
    if focus and not searchBox:HasFocus() then
        searchBox:SetFocus()
        searchBox:SetCursorPosition(#(searchBox:GetText() or ""))
    end
end

local function RefreshDropdownSearch(dropdown, delay)
    if dropdown.nskinMenuSearchTimer then
        dropdown.nskinMenuSearchTimer:Cancel()
        dropdown.nskinMenuSearchTimer = nil
    end
    if not C_Timer or not C_Timer.NewTimer then return end
    dropdown.nskinMenuSearchGeneration =
        (dropdown.nskinMenuSearchGeneration or 0) + 1
    local generation = dropdown.nskinMenuSearchGeneration
    dropdown.nskinMenuSearchTimer = C_Timer.NewTimer(delay, function()
        dropdown.nskinMenuSearchTimer = nil
        if dropdown.nskinOwnedDropdown then
            if dropdown.menu and dropdown.menu:IsShown()
                and dropdown.nskinMenuSearchGeneration == generation
            then
                dropdown:RebuildOwnedMenu()
                local searchBox = dropdown.nskinMenuSearchBox
                if searchBox and not searchBox:HasFocus() then searchBox:SetFocus() end
            end
            return
        end
        if not dropdown.menu
            or dropdown.nskinMenuSearchGeneration ~= generation
        then return end
        dropdown.nskinMenuSearchReopening = true
        dropdown:CloseMenu()
        dropdown:OpenMenu()
        dropdown.nskinMenuSearchReopening = nil
        if not dropdown.menu
            or dropdown.nskinMenuSearchGeneration ~= generation
        then return end
        SkinAddonDropdownMenu(dropdown.menu)
        local scrollBox = dropdown.menu.ScrollBox
        if scrollBox and scrollBox.ScrollToBegin then scrollBox:ScrollToBegin() end
        PositionDropdownSearchBox(dropdown, dropdown.menu, true)
    end)
end

local function EnsureDropdownSearchBox(dropdown)
    if dropdown.nskinMenuSearchBox then return dropdown.nskinMenuSearchBox end
    local searchBox = CreateFrame("EditBox", nil, UIParent)
    searchBox:SetAutoFocus(false)
    searchBox:SetFontObject(GameFontHighlightSmall)
    searchBox:SetJustifyH("LEFT")
    searchBox:SetJustifyV("MIDDLE")
    searchBox:SetTextInsets(24, 8, 0, 0)
    searchBox:EnableMouse(true)
    searchBox:EnableKeyboard(true)
    if searchBox.SetPropagateMouseClicks then
        searchBox:SetPropagateMouseClicks(false)
    end
    if searchBox.SetPropagateKeyboardInput then
        searchBox:SetPropagateKeyboardInput(false)
    end

    searchBox.background = searchBox:CreateTexture(nil, "BACKGROUND")
    searchBox.background:SetAllPoints()
    searchBox.background:SetColorTexture(unpack(NSkin:GetStyle("window").background))
    searchBox.separator = searchBox:CreateTexture(nil, "OVERLAY")
    searchBox.separator:SetPoint("BOTTOMLEFT")
    searchBox.separator:SetPoint("BOTTOMRIGHT")
    searchBox.separator:SetHeight(1)
    searchBox.separator:SetColorTexture(unpack(NSkin:GetSharedBorderColor()))
    searchBox.searchIcon = searchBox:CreateTexture(nil, "OVERLAY")
    searchBox.searchIcon:SetSize(14, 14)
    searchBox.searchIcon:SetPoint("LEFT", 6, 0)
    searchBox.searchIcon:SetAtlas("common-search-magnifyingglass")
    searchBox.placeholder = searchBox:CreateFontString(nil, "OVERLAY",
        "GameFontDisableSmall")
    searchBox.placeholder:SetPoint("LEFT", searchBox, "LEFT", 24, 0)
    searchBox.placeholder:SetPoint("RIGHT", searchBox, "RIGHT", -8, 0)
    searchBox.placeholder:SetJustifyH("LEFT")
    searchBox.placeholder:SetJustifyV("MIDDLE")
    searchBox.placeholder:SetText("Search...")

    searchBox:SetScript("OnMouseDown", function(self) self:SetFocus() end)
    searchBox:SetScript("OnEscapePressed", function()
        if dropdown.menu then dropdown:CloseMenu() end
    end)
    searchBox:SetScript("OnEditFocusGained", function(self)
        if self.SetPropagateKeyboardInput then
            self:SetPropagateKeyboardInput(false)
        end
    end)
    searchBox:SetScript("OnKeyDown", function(self, key)
        if key == "BACKSPACE" or key == "DELETE" then
            self.nskinDeleting = true
            if dropdown.nskinMenuSearchTimer then
                dropdown.nskinMenuSearchTimer:Cancel()
                dropdown.nskinMenuSearchTimer = nil
            end
        end
    end)
    searchBox:SetScript("OnKeyUp", function(self, key)
        if key == "BACKSPACE" or key == "DELETE" then
            self.nskinDeleting = nil
            RefreshDropdownSearch(dropdown, 0.05)
        end
    end)
    searchBox:SetScript("OnTextChanged", function(self, userInput)
        local text = self:GetText() or ""
        self.placeholder:SetShown(text == "")
        if not userInput or text == (dropdown.nskinMenuSearchText or "") then return end
        dropdown.nskinMenuSearchText = text
        if not self.nskinDeleting then RefreshDropdownSearch(dropdown, 0.2) end
    end)
    searchBox:Hide()
    dropdown.nskinMenuSearchBox = searchBox
    return searchBox
end

local function AddDropdownMenuSearch(dropdown, rootDescription, choices)
    local entries = 0
    for i = 1, #(choices or {}) do
        if not choices[i].divider and not choices[i].title then
            entries = entries + 1
        end
    end
    if entries <= DROPDOWN_MENU_SCROLL_THRESHOLD
        or not rootDescription.CreateFrame
    then
        dropdown.nskinHasMenuSearch = nil
        dropdown.nskinMenuSearchText = nil
        return nil
    end

    dropdown.nskinHasMenuSearch = true
    local filter = tostring(dropdown.nskinMenuSearchText or ""):lower()
    local searchWidth = math.max(200, dropdown:GetWidth())
    if rootDescription.SetMinimumWidth then
        rootDescription:SetMinimumWidth(searchWidth)
    end
    if rootDescription.SetMaximumWidth then
        rootDescription:SetMaximumWidth(searchWidth)
    end
    local matches = 0
    for i = 1, #choices do
        if DropdownChoiceMatches(choices[i], filter) then matches = matches + 1 end
    end
    if matches <= DROPDOWN_MENU_SCROLL_THRESHOLD then
        local searchDescription = rootDescription:CreateFrame()
        searchDescription:AddInitializer(function(container)
            container:SetSize(searchWidth, 28)
            return searchWidth, 28
        end)
    end
    return filter
end

local function SkinDropdownScrollArrow(button, rotation)
    if not button or not button.Texture then return end
    local function ApplyArrowSkin()
        button.Texture:SetTexture(DROPDOWN_ARROW_TEXTURE)
        button.Texture:SetRotation(rotation)
        button.Texture:SetVertexColor(1, 1, 1, button:IsEnabled() and 1 or 0.4)
        button.Texture:SetSize(14, 14)
        button.Texture:ClearAllPoints()
        button.Texture:SetPoint("CENTER")
    end
    local data = NSkin:GetSkinData(button, DROPDOWN_MENU_SKIN)
    if not data.arrowHooked then
        data.arrowHooked = true
        for _, script in ipairs({ "OnEnter", "OnLeave", "OnMouseDown",
            "OnMouseUp", "OnEnable", "OnDisable" }) do
            button:HookScript(script, ApplyArrowSkin)
        end
    end
    ApplyArrowSkin()
end

local function SkinAddonDropdownScrollBar(menu)
    local scrollBar = menu and menu.ScrollBar
    if not scrollBar or not scrollBar:IsShown() then return end
    local data = NSkin:GetSkinData(menu, DROPDOWN_MENU_SKIN)
    local nativeBarWidth = scrollBar:GetWidth()
    scrollBar:SetWidth(14)
    if not data.scrollLayoutAdjusted then
        data.scrollLayoutAdjusted = true
        local scrollBox = menu.ScrollBox
        local _, _, _, left, top = scrollBox:GetPoint(1)
        local _, _, _, right, bottom = scrollBox:GetPoint(2)
        left, top = left or 0, top or 0
        right, bottom = right or 0, bottom or 0
        nativeBarWidth = math.abs(right) > 0
            and math.min(nativeBarWidth, math.abs(right)) or 0
        local reclaimedWidth = nativeBarWidth + 10
        menu:SetWidth(math.max(1, menu:GetWidth() - reclaimedWidth))
        scrollBox:ClearAllPoints()
        scrollBox:SetPoint("TOPLEFT", menu, "TOPLEFT", left, top)
        scrollBox:SetPoint("BOTTOMRIGHT", menu, "BOTTOMRIGHT",
            -(math.max(0, math.abs(right) - nativeBarWidth)), bottom)
        scrollBar:ClearAllPoints()
        scrollBar:SetPoint("TOPRIGHT", menu, "TOPRIGHT", -1, top)
        scrollBar:SetPoint("BOTTOMRIGHT", menu, "BOTTOMRIGHT", -1, bottom)
    end
    SkinDropdownScrollArrow(scrollBar.Back, math.pi)
    SkinDropdownScrollArrow(scrollBar.Forward, 0)

    local track = scrollBar.Track
    if track then
        for _, region in ipairs({ track:GetRegions() }) do
            if region.IsObjectType and region:IsObjectType("Texture") then
                region:SetColorTexture(0, 0, 0, 0.65)
            end
        end
    end
    local thumb = track and track.Thumb
    if thumb then
        local function ApplyThumbSkin()
            local accent = NSkin:GetAccentColor()
            for _, region in ipairs({ thumb:GetRegions() }) do
                if region.IsObjectType and region:IsObjectType("Texture") then
                    region:SetColorTexture(unpack(accent))
                end
            end
        end
        local data = NSkin:GetSkinData(thumb, DROPDOWN_MENU_SKIN)
        if not data.thumbHooked then
            data.thumbHooked = true
            for _, script in ipairs({ "OnSizeChanged", "OnEnter", "OnLeave",
                "OnMouseDown", "OnMouseUp", "OnEnable", "OnDisable" }) do
                thumb:HookScript(script, ApplyThumbSkin)
            end
        end
        ApplyThumbSkin()
    end
end

local function HideAddonDropdownMenuSkin(menu)
    if not menu then return end
    local data = NSkin:GetSkinData(menu, DROPDOWN_MENU_SKIN, false)
    if not data then return end
    if data.borderFrame then data.borderFrame:Hide() end
    data.scrollLayoutAdjusted = nil
    data.searchInsetAdjusted = nil
end

SkinAddonDropdownMenu = function(menu)
    if not menu or not menu:IsShown() then return end
    if menu.nskinOwnedMenu then
        NSkin:CreateFlatBackground(menu, "NSkinOwnedDropdownMenu",
            NSkin:GetStyle("window").background, NSkin:GetSharedBorderColor())
        NSkin:SetPixelBorderSize(NSkin:GetPixelBorder(menu,
            "NSkinOwnedDropdownMenuBorder"), 1)
        return
    end
    local data = NSkin:GetSkinData(menu, DROPDOWN_MENU_SKIN)

    local backgroundColor = NSkin:GetStyle("window").background
    for _, region in ipairs({ menu:GetRegions() }) do
        if region.IsObjectType and region:IsObjectType("Texture") then
            region:SetColorTexture(unpack(backgroundColor))
            region:ClearAllPoints()
            region:SetPoint("TOPLEFT", menu, "TOPLEFT", 1, -1)
            region:SetPoint("BOTTOMRIGHT", menu, "BOTTOMRIGHT", -1, 1)
            region:SetAlpha(1)
            region:Show()
        end
    end

    if not data.borderFrame then
        local borderFrame = CreateFrame("Frame", nil, UIParent)
        borderFrame:EnableMouse(false)
        data.borderFrame = borderFrame
        NSkin:CreatePixelBorder(borderFrame, "NSkinOptionsDropdownMenuBorder",
            1, NSkin:GetSharedBorderColor(), false, borderFrame)
    end
    local borderFrame = data.borderFrame
    borderFrame:ClearAllPoints()
    borderFrame:SetAllPoints(menu)
    borderFrame:SetFrameStrata(menu:GetFrameStrata())
    borderFrame:SetFrameLevel(menu:GetFrameLevel() + 1)
    local border = NSkin:GetPixelBorder(
        borderFrame, "NSkinOptionsDropdownMenuBorder")
    NSkin:SetPixelBorderColor(border, unpack(NSkin:GetSharedBorderColor()))
    NSkin:SetPixelBorderSize(border, 1)
    NSkin:SetPixelBorderShown(border, true)
    borderFrame:Show()
    if not menu.nskinOwnedMenu then SkinAddonDropdownScrollBar(menu) end
end

local function SkinAddonDropdown(dropdown)
    if not dropdown then return end
    if not dropdown.nskinOwnedDropdown then
        NSkin:HideTextureRegions(dropdown)
        for _, child in ipairs({ dropdown:GetChildren() }) do
            NSkin:HideTextureRegions(child)
        end
    end
    local background = NSkin:CreateFlatBackground(dropdown, "NSkinOptionsDropdown",
        NSkin:GetStyle("button").background, NSkin:GetSharedBorderColor())
    if background then background:SetAlpha(1) end
    local border = NSkin:GetPixelBorder(dropdown, "NSkinOptionsDropdownBorder")
    NSkin:SetPixelBorderColor(border, unpack(NSkin:GetSharedBorderColor()))
    NSkin:SetPixelBorderSize(border, 1)
    NSkin:SetPixelBorderShown(border, true)
    if border then
        for _, edge in ipairs({ border.top, border.bottom, border.left, border.right }) do
            edge:SetAlpha(1)
            edge:Show()
        end
    end
    if not dropdown.nskinArrow then
        local arrow = dropdown:CreateTexture(nil, "OVERLAY")
        arrow:SetSize(14, 14)
        arrow:SetPoint("RIGHT", dropdown, "RIGHT", -8, 0)
        arrow:SetTexture(DROPDOWN_ARROW_TEXTURE)
        dropdown.nskinArrow = arrow
    end
    dropdown.nskinArrow:SetTexture(DROPDOWN_ARROW_TEXTURE)
    dropdown.nskinArrow:SetAlpha(1)
    dropdown.nskinArrow:SetVertexColor(1, 1, 1, dropdown:IsEnabled() and 1 or 0.4)
    dropdown.nskinArrow:Show()
    if not dropdown.nskinOwnedDropdown
        and not dropdown.nskinMenuSkinHooked and _G.hooksecurefunc
    then
        dropdown.nskinMenuSkinHooked = true
        _G.hooksecurefunc(dropdown, "OnMenuOpened", function(_, menu)
            menu = menu or dropdown.menu
            if menu and C_Timer and C_Timer.After then
                C_Timer.After(0, function()
                    if dropdown.menu == menu and menu:IsShown() then
                        SkinAddonDropdownMenu(menu)
                        if dropdown.nskinHasMenuSearch then
                            local searchBox = EnsureDropdownSearchBox(dropdown)
                            searchBox.background:SetColorTexture(unpack(
                                NSkin:GetStyle("window").background))
                            searchBox.separator:SetColorTexture(unpack(
                                NSkin:GetSharedBorderColor()))
                            searchBox:SetText(dropdown.nskinMenuSearchText or "")
                            if menu.ScrollBox and menu.ScrollBox.ScrollToBegin then
                                menu.ScrollBox:ScrollToBegin()
                            end
                            PositionDropdownSearchBox(dropdown, menu, true)
                        end
                    end
                end)
            else
                SkinAddonDropdownMenu(menu)
            end
        end)
        _G.hooksecurefunc(dropdown, "OnMenuClosed", function(_, menu)
            HideAddonDropdownMenuSkin(menu or dropdown.menu)
            if dropdown.nskinMenuSearchReopening then return end
            if dropdown.nskinMenuSearchTimer then
                dropdown.nskinMenuSearchTimer:Cancel()
                dropdown.nskinMenuSearchTimer = nil
            end
            if dropdown.nskinMenuSearchBox then
                dropdown.nskinMenuSearchBox:ClearFocus()
                dropdown.nskinMenuSearchBox:Hide()
                dropdown.nskinMenuSearchBox:SetText("")
            end
            dropdown.nskinMenuSearchText = nil
            dropdown.nskinMenuSearchGeneration =
                (dropdown.nskinMenuSearchGeneration or 0) + 1
        end)
    end
    for _, region in ipairs({ dropdown:GetRegions() }) do
        if region.GetObjectType and region:GetObjectType() == "FontString" then
            region:SetWordWrap(false)
            if region.SetNonSpaceWrap then region:SetNonSpaceWrap(true) end
            region:ClearAllPoints()
            region:SetPoint("LEFT", dropdown, "LEFT", 8, 0)
            region:SetPoint("RIGHT", dropdown, "RIGHT", -28, 0)
            region:SetHeight(math.max(1, dropdown:GetHeight() - 4))
            region:SetJustifyH("LEFT")
            region:SetJustifyV("MIDDLE")
        end
    end
end

local function CreateOwnedMenuDescription(dropdown)
    local root = { entries = {}, minimumWidth = dropdown:GetWidth() }
    local function CreateEntry(kind, label, isSelected, responder, value)
        local entry = { kind = kind, label = label, isSelected = isSelected,
            responder = responder, value = value, enabled = true,
            initializers = {} }
        function entry:SetEnabled(enabled) self.enabled = enabled == true end
        function entry:AddInitializer(initializer)
            if type(initializer) == "function" then
                self.initializers[#self.initializers + 1] = initializer
            end
        end
        root.entries[#root.entries + 1] = entry
        return entry
    end
    function root:SetScrollMode(height) self.maximumHeight = tonumber(height) end
    function root:SetMinimumWidth(width)
        self.minimumWidth = math.max(self.minimumWidth, tonumber(width) or 0)
    end
    function root:SetMaximumWidth(width) self.maximumWidth = tonumber(width) end
    function root:CreateDivider() return CreateEntry("DIVIDER") end
    function root:CreateTitle(label) return CreateEntry("TITLE", label) end
    function root:CreateFrame()
        local description = { initializers = {} }
        function description:AddInitializer(initializer)
            self.initializers[#self.initializers + 1] = initializer
        end
        return description
    end
    function root:CreateRadio(label, isSelected, responder, value)
        return CreateEntry("RADIO", label, isSelected, responder, value)
    end
    return root
end

local function CreateOwnedDropdown(parent)
    local dropdown = CreateFrame("Button", nil, parent)
    dropdown.nskinOwnedDropdown = true
    dropdown:RegisterForClicks("LeftButtonUp")
    dropdown.text = dropdown:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    dropdown.text:SetText("")

    local blocker = CreateFrame("Button", nil, UIParent)
    blocker:SetAllPoints(UIParent)
    blocker:SetFrameStrata("FULLSCREEN_DIALOG")
    blocker:EnableMouse(true)
    blocker:Hide()

    local menu = CreateFrame("Frame", nil, UIParent)
    menu.nskinOwnedMenu = true
    menu:SetFrameStrata("FULLSCREEN_DIALOG")
    menu:SetClampedToScreen(true)
    menu:EnableMouse(true)
    NSkin:CreateFlatBackground(menu, "NSkinOwnedDropdownMenu",
        NSkin:GetStyle("window").background, NSkin:GetSharedBorderColor())
    NSkin:SetPixelBorderSize(NSkin:GetPixelBorder(menu,
        "NSkinOwnedDropdownMenuBorder"), 1)
    menu:Hide()
    dropdown.menu = menu

    local scrollFrame = CreateFrame("ScrollFrame", nil, menu)
    scrollFrame:SetClipsChildren(true)
    scrollFrame:EnableMouseWheel(true)
    menu.ScrollBox = scrollFrame
    local content = CreateFrame("Frame", nil, scrollFrame)
    scrollFrame:SetScrollChild(content)
    menu.content = content

    local scrollBar = CreateFrame("Frame", nil, menu)
    scrollBar:SetWidth(12)
    scrollBar:SetPoint("TOPRIGHT", menu, "TOPRIGHT", -1, -1)
    scrollBar:SetPoint("BOTTOMRIGHT", menu, "BOTTOMRIGHT", -1, 1)
    menu.ScrollBar = scrollBar
    local up = CreateFrame("Button", nil, scrollBar)
    up:SetPoint("TOP")
    up:SetSize(12, 12)
    up.Texture = up:CreateTexture(nil, "OVERLAY")
    up.Texture:SetAllPoints()
    up.Texture:SetTexture(DROPDOWN_ARROW_TEXTURE)
    up.Texture:SetRotation(math.pi)
    local down = CreateFrame("Button", nil, scrollBar)
    down:SetPoint("BOTTOM")
    down:SetSize(12, 12)
    down.Texture = down:CreateTexture(nil, "OVERLAY")
    down.Texture:SetAllPoints()
    down.Texture:SetTexture(DROPDOWN_ARROW_TEXTURE)
    local track = scrollBar:CreateTexture(nil, "BACKGROUND")
    track:SetPoint("TOP", up, "BOTTOM", 0, -1)
    track:SetPoint("BOTTOM", down, "TOP", 0, 1)
    track:SetWidth(2)
    track:SetColorTexture(0.25, 0.25, 0.25, 1)
    local thumb = scrollBar:CreateTexture(nil, "ARTWORK")
    thumb:SetWidth(6)
    thumb:SetColorTexture(unpack(NSkin:GetAccentColor()))
    scrollBar.thumb = thumb

    local function UpdateScrollBar()
        local range = math.max(0, content:GetHeight() - scrollFrame:GetHeight())
        local shown = dropdown.nskinHasMenuSearch == true and range > 0
        scrollBar:SetShown(shown)
        if not shown then
            scrollFrame:SetVerticalScroll(0)
            return
        end
        local trackHeight = math.max(1, scrollBar:GetHeight() - 26)
        local thumbHeight = math.max(18,
            trackHeight * scrollFrame:GetHeight() / math.max(1, content:GetHeight()))
        local offsetRange = math.max(0, trackHeight - thumbHeight)
        local ratio = range > 0 and scrollFrame:GetVerticalScroll() / range or 0
        thumb:ClearAllPoints()
        thumb:SetPoint("TOP", scrollBar, "TOP", 0, -13 - offsetRange * ratio)
        thumb:SetHeight(thumbHeight)
    end

    local function ScrollBy(amount)
        local range = math.max(0, content:GetHeight() - scrollFrame:GetHeight())
        scrollFrame:SetVerticalScroll(Clamp(
            scrollFrame:GetVerticalScroll() + amount, 0, range))
        UpdateScrollBar()
    end
    scrollFrame:SetScript("OnMouseWheel", function(_, delta) ScrollBy(-delta * 48) end)
    scrollFrame:SetScript("OnVerticalScroll", UpdateScrollBar)
    up:SetScript("OnClick", function() ScrollBy(-48) end)
    down:SetScript("OnClick", function() ScrollBy(48) end)

    local function ClearRows()
        for i = 1, #(dropdown.nskinRows or {}) do
            dropdown.nskinRows[i]:Hide()
        end
        dropdown.nskinRows = {}
    end

    local function CreateRow(entry, index, y, width)
        dropdown.nskinRowPool = dropdown.nskinRowPool or {}
        local row = dropdown.nskinRowPool[index]
        if not row then
            row = CreateFrame("Button", nil, content)
            row.nskinOwnedMenuRow = true
            row.line = row:CreateTexture(nil, "ARTWORK")
            row.line:SetPoint("LEFT", 6, 0)
            row.line:SetPoint("RIGHT", -6, 0)
            row.line:SetHeight(1)
            row.fontString = row:CreateFontString(nil, "OVERLAY",
                "GameFontHighlightSmall")
            row.indicator = CreateFrame("Frame", nil, row)
            row.indicator:SetSize(14, 14)
            row.indicator:SetPoint("LEFT", 6, 0)
            NSkin:CreateFlatBackground(row.indicator,
                "NSkinOwnedDropdownCheckbox",
                NSkin:GetStyle("button").background,
                NSkin:GetSharedBorderColor())
            NSkin:SetPixelBorderSize(NSkin:GetPixelBorder(row.indicator,
                "NSkinOwnedDropdownCheckboxBorder"), 1)
            row.indicator.check = row.indicator:CreateTexture(nil, "ARTWORK")
            row.indicator.check:SetPoint("TOPLEFT", 3, -3)
            row.indicator.check:SetPoint("BOTTOMRIGHT", -3, 3)
            row.indicator.check:SetColorTexture(unpack(NSkin:GetAccentColor()))
            dropdown.nskinRowPool[index] = row
        end
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -y)
        row:SetScript("OnClick", nil)
        row:SetScript("OnEnter", nil)
        row.line:Hide()
        row.fontString:Hide()
        row.indicator:Hide()
        if row.nskinColorFill then row.nskinColorFill:Hide() end
        if entry.kind == "DIVIDER" then
            row:SetSize(width, 9)
            row.line:SetColorTexture(unpack(NSkin:GetSharedBorderColor()))
            row.line:Show()
            row:EnableMouse(false)
            row:Show()
            return row, 9
        end
        row:SetSize(width, OWNED_DROPDOWN_ROW_HEIGHT)
        row:EnableMouse(entry.kind == "RADIO")
        row.fontString:SetFontObject(entry.kind == "TITLE"
            and GameFontNormalSmall or GameFontHighlightSmall)
        row.fontString:ClearAllPoints()
        row.fontString:SetPoint("LEFT", row, "LEFT",
            entry.kind == "RADIO" and 25 or 8, 0)
        row.fontString:SetPoint("RIGHT", row, "RIGHT", -6, 0)
        row.fontString:SetJustifyH("LEFT")
        row.fontString:SetText(entry.label or "")
        row.fontString:Show()
        if entry.kind == "RADIO" then
            local selected = type(entry.isSelected) == "function"
                and entry.isSelected(entry.value) == true
            NSkin:CreateFlatBackground(row.indicator,
                "NSkinOwnedDropdownCheckbox",
                NSkin:GetStyle("button").background,
                NSkin:GetSharedBorderColor())
            local indicatorBorder = NSkin:GetPixelBorder(row.indicator,
                "NSkinOwnedDropdownCheckboxBorder")
            NSkin:SetPixelBorderColor(indicatorBorder,
                unpack(NSkin:GetSharedBorderColor()))
            NSkin:SetPixelBorderSize(indicatorBorder, 1)
            NSkin:SetPixelBorderShown(indicatorBorder, true)
            row.indicator.check:SetColorTexture(unpack(NSkin:GetAccentColor()))
            row.indicator.check:SetShown(selected)
            row.indicator:Show()
            row:SetEnabled(entry.enabled)
            row:SetAlpha(entry.enabled and 1 or 0.35)
            row:SetScript("OnClick", function()
                if not entry.enabled then return end
                if type(entry.responder) == "function" then
                    entry.responder(entry.value)
                end
                dropdown:CloseMenu()
            end)
            if not row.highlight then
                row.highlight = row:CreateTexture(nil, "HIGHLIGHT")
                row.highlight:SetAllPoints()
                row.highlight:SetColorTexture(1, 1, 1, 0.12)
            end
        else
            row:SetEnabled(true)
            row:SetAlpha(1)
        end
        row.AttachTexture = function(self)
            return self:CreateTexture(nil, "ARTWORK")
        end
        for i = 1, #entry.initializers do
            entry.initializers[i](row, entry, menu)
        end
        row:Show()
        return row, OWNED_DROPDOWN_ROW_STEP
    end

    function dropdown:RebuildOwnedMenu()
        ClearRows()
        local root = CreateOwnedMenuDescription(self)
        if type(self.nskinGenerator) == "function" then
            self.nskinGenerator(self, root)
        end
        local width = math.max(self:GetWidth(), root.minimumWidth or 0)
        if root.maximumWidth then width = math.min(width, root.maximumWidth) end
        local y = 0
        for i = 1, #root.entries do
            local row, height = CreateRow(root.entries[i], i, y, width - 2)
            self.nskinRows[#self.nskinRows + 1] = row
            y = y + height
        end
        local contentHeight = y > 0 and (y + 1) or 1
        content:SetSize(width - 2, contentHeight)
        local searchHeight = self.nskinHasMenuSearch and 28 or 0
        local maximum = root.maximumHeight or DROPDOWN_MENU_MAX_HEIGHT
        local viewportHeight = math.min(contentHeight,
            math.max(OWNED_DROPDOWN_ROW_HEIGHT, maximum - searchHeight - 2))
        menu:SetSize(width, viewportHeight + searchHeight + 2)
        scrollFrame:ClearAllPoints()
        scrollFrame:SetPoint("TOPLEFT", menu, "TOPLEFT", 1, -1 - searchHeight)
        scrollFrame:SetPoint("BOTTOMRIGHT", menu, "BOTTOMRIGHT", -1, 1)
        scrollBar:ClearAllPoints()
        scrollBar:SetPoint("TOPRIGHT", menu, "TOPRIGHT", -1,
            -1 - searchHeight)
        scrollBar:SetPoint("BOTTOMRIGHT", menu, "BOTTOMRIGHT", -1, 1)
        scrollFrame:SetVerticalScroll(0)
        UpdateScrollBar()
        if self.nskinHasMenuSearch then
            local searchBox = EnsureDropdownSearchBox(self)
            searchBox.background:SetColorTexture(unpack(NSkin:GetStyle("window").background))
            searchBox.separator:SetColorTexture(unpack(NSkin:GetSharedBorderColor()))
            local searchText = self.nskinMenuSearchText or ""
            if searchBox:GetText() ~= searchText then
                searchBox:SetText(searchText)
                searchBox:SetCursorPosition(#searchText)
            end
            searchBox:ClearAllPoints()
            searchBox:SetPoint("TOPLEFT", menu, "TOPLEFT", 1, -1)
            searchBox:SetPoint("TOPRIGHT", menu, "TOPRIGHT", -1, -1)
            searchBox:SetHeight(28)
            searchBox:SetFrameStrata(menu:GetFrameStrata())
            searchBox:SetFrameLevel(menu:GetFrameLevel() + 10)
            searchBox:Show()
            if not searchBox:HasFocus() then searchBox:SetFocus() end
        end
        SkinAddonDropdownMenu(menu)
    end

    function dropdown:SetDefaultText(text)
        self.nskinDefaultText = text or ""
        self.text:SetText(self.nskinDefaultText)
    end
    function dropdown:SetupMenu(generator) self.nskinGenerator = generator end
    function dropdown:GenerateMenu()
        if self.menu:IsShown() then self:RebuildOwnedMenu() end
    end
    function dropdown:OpenMenu()
        if not self:IsEnabled() or not self.nskinGenerator then return end
        blocker:SetFrameLevel(math.max(1, self:GetFrameLevel() + 100))
        menu:SetFrameLevel(blocker:GetFrameLevel() + 1)
        menu:ClearAllPoints()
        menu:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -1)
        blocker:Show()
        menu:Show()
        self:RebuildOwnedMenu()
    end
    function dropdown:CloseMenu()
        menu:Hide()
        blocker:Hide()
        HideAddonDropdownMenuSkin(menu)
        if self.nskinMenuSearchTimer then
            self.nskinMenuSearchTimer:Cancel()
            self.nskinMenuSearchTimer = nil
        end
        if self.nskinMenuSearchBox then
            self.nskinMenuSearchBox:ClearFocus()
            self.nskinMenuSearchBox:Hide()
            self.nskinMenuSearchBox:SetText("")
        end
        self.nskinMenuSearchText = nil
    end
    dropdown:SetScript("OnClick", function(self)
        if self.menu:IsShown() then self:CloseMenu() else self:OpenMenu() end
    end)
    dropdown:HookScript("OnHide", function(self) self:CloseMenu() end)
    blocker:SetScript("OnClick", function() dropdown:CloseMenu() end)
    menu:SetScript("OnKeyDown", function(_, key)
        if key == "ESCAPE" then dropdown:CloseMenu() end
    end)
    SkinAddonDropdown(dropdown)
    return dropdown
end

local OPTION_MENUS = NSkin._componentOptionMenus
OPTION_MENUS.CreateOwnedDropdown = CreateOwnedDropdown
OPTION_MENUS.SkinAddonDropdown = SkinAddonDropdown
OPTION_MENUS.ConfigureDropdownMenuScroll = ConfigureDropdownMenuScroll
OPTION_MENUS.AddDropdownMenuSearch = AddDropdownMenuSearch
OPTION_MENUS.DropdownChoiceMatches = DropdownChoiceMatches
