local _, NSkin = ...

local optionGroups = {}
local viewsByGroup = {}
local DEFAULT_OPTIONS_WIDTH = 760
local DEFAULT_OPTIONS_HEIGHT = 560
local MIN_OPTIONS_WIDTH = 640
local MIN_OPTIONS_HEIGHT = 420
local COMPACT_OPTIONS_WIDTH = 502
local COMPACT_GRID_HEIGHT = 48
local COMPACT_GRID_PADDING = 8
local COMPACT_GRID_LABEL_WIDTH = 64
local COMPACT_GRID_CENTER_WIDTH = 28
local COMPACT_GRID_DEBUG_BORDER = { 1, 1, 0, 1 }
local DROPDOWN_MENU_MAX_HEIGHT = 300
local DROPDOWN_MENU_SCROLL_THRESHOLD = 12
local OWNED_DROPDOWN_ROW_HEIGHT = 24
local OWNED_DROPDOWN_ROW_STEP = OWNED_DROPDOWN_ROW_HEIGHT - 1
local compactGridDebugEnabled = false
local compactGridDebugRecords = {}
local BUILT_IN_FONTS = {
    { value = "Fonts\\FRIZQT__.TTF", label = "Friz Quadrata", priority = 1 },
    { value = "Fonts\\ARIALN.TTF", label = "Arial Narrow", priority = 2 },
    { value = "Fonts\\MORPHEUS.TTF", label = "Morpheus", priority = 3 },
    { value = "Fonts\\SKURRI.TTF", label = "Skurri", priority = 4 },
}

function NSkin:GetAvailableFontOptions(includeGlobal)
    local fonts, paths = {}, {}
    local function Add(label, path, priority)
        if type(label) ~= "string" or label == ""
            or type(path) ~= "string" or path == ""
        then return end
        local normalized = path:lower()
        if paths[normalized] then return end
        paths[normalized] = true
        fonts[#fonts + 1] = { value = path, label = label,
            priority = priority or 100 }
    end
    for i = 1, #BUILT_IN_FONTS do
        local font = BUILT_IN_FONTS[i]
        Add(font.label, font.value, font.priority)
    end
    if _G.LibStub then
        local ok, media = pcall(function()
            return _G.LibStub("LibSharedMedia-3.0", true)
        end)
        local registered = ok and media and media:HashTable("font")
        if registered then
            for name, path in pairs(registered) do Add(name, path) end
        end
    end
    table.sort(fonts, function(left, right)
        if left.priority ~= right.priority then
            return left.priority < right.priority
        end
        return left.label:lower() < right.label:lower()
    end)
    if includeGlobal then
        table.insert(fonts, 1, { divider = true })
        table.insert(fonts, 1, {
            value = "__NSKIN_GLOBAL__", label = "NSkin Global Font",
        })
    end
    return fonts
end

local function SetDebugRecordShown(record, shown)
    if record.kind == "CELL" then
        if shown and not record.border then
            record.border = NSkin:CreatePixelBorder(record.frame,
                "NSkinCompactGridCell", 1, COMPACT_GRID_DEBUG_BORDER,
                false, record.frame)
        end
        if record.border then NSkin:SetPixelBorderShown(record.border, shown) end
    else
        if shown and not record.texture then
            local divider = record.parent:CreateTexture(nil, "OVERLAY")
            divider:SetColorTexture(unpack(COMPACT_GRID_DEBUG_BORDER))
            divider:SetSize(1, COMPACT_GRID_HEIGHT)
            divider:SetPoint("TOP", record.label,
                record.mirrored and "TOPLEFT" or "TOPRIGHT", 0, 4)
            record.texture = divider
        end
        if record.texture then record.texture:SetShown(shown) end
    end
end

function NSkin:IsCompactGridDebugEnabled()
    return compactGridDebugEnabled
end

function NSkin:SetCompactGridDebugEnabled(enabled)
    enabled = enabled == true
    if compactGridDebugEnabled == enabled then return true end
    compactGridDebugEnabled = enabled
    for i = 1, #compactGridDebugRecords do
        SetDebugRecordShown(compactGridDebugRecords[i], enabled)
    end
    return true
end

local function AddCompactGridCellBorder(cell)
    local record = { kind = "CELL", frame = cell }
    compactGridDebugRecords[#compactGridDebugRecords + 1] = record
    if compactGridDebugEnabled then SetDebugRecordShown(record, true) end
end

local function AddCompactGridControlDivider(parent, label, mirrored)
    local record = { kind = "DIVIDER", parent = parent,
        label = label, mirrored = mirrored == true }
    compactGridDebugRecords[#compactGridDebugRecords + 1] = record
    if compactGridDebugEnabled then SetDebugRecordShown(record, true) end
end

local function Clamp(value, minimum, maximum)
    return math.max(minimum, math.min(maximum, value))
end

function NSkin:GetOptionsWindowSize()
    local profile = self:GetProfile()
    local editor = profile.editor
    local width = editor and tonumber(editor.optionsWidth) or DEFAULT_OPTIONS_WIDTH
    local height = editor and tonumber(editor.optionsHeight) or DEFAULT_OPTIONS_HEIGHT
    local maximumWidth = math.max(MIN_OPTIONS_WIDTH, (UIParent:GetWidth() or 1920) - 40)
    local maximumHeight = math.max(MIN_OPTIONS_HEIGHT, (UIParent:GetHeight() or 1080) - 40)
    return Clamp(width, MIN_OPTIONS_WIDTH, maximumWidth),
        Clamp(height, MIN_OPTIONS_HEIGHT, maximumHeight),
        maximumWidth, maximumHeight
end

function NSkin:SetOptionsWindowSize(width, height)
    width, height = tonumber(width), tonumber(height)
    if not width or not height then return false end
    local _, _, maximumWidth, maximumHeight = self:GetOptionsWindowSize()
    width = math.floor(Clamp(width, MIN_OPTIONS_WIDTH, maximumWidth) + 0.5)
    height = math.floor(Clamp(height, MIN_OPTIONS_HEIGHT, maximumHeight) + 0.5)

    local profile = self:GetProfile()
    profile.editor = profile.editor or {}
    profile.editor.optionsWidth = width == DEFAULT_OPTIONS_WIDTH and nil or width
    profile.editor.optionsHeight = height == DEFAULT_OPTIONS_HEIGHT and nil or height
    if not next(profile.editor) then profile.editor = nil end
    return true
end


function NSkin:CreateOptionsPage(parent)
    if not parent then return nil end
    local page = CreateFrame("Frame", nil, parent)
    page:SetPoint("TOPLEFT")
    page:SetPoint("TOPRIGHT")
    page:SetHeight(1)
    page.sectionDividers = {}

    function page:SetContentHeight(height)
        height = math.max(1, math.ceil(tonumber(height) or 1))
        self.contentHeight = height
        self:SetHeight(height)
        if parent.activePage == self then parent:SetHeight(height) end
    end

    function page:ApplyStructureTheme()
        local color = NSkin:GetStyle("window").header.divider
        for i = 1, #self.sectionDividers do
            self.sectionDividers[i]:SetColorTexture(unpack(color))
        end
    end

    return page
end

function NSkin:CreateOptionsSection(page, title, offset)
    if not page or type(title) ~= "string" then return nil, offset end
    offset = math.max(0, tonumber(offset) or 0)
    local heading = page:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    heading:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -offset)
    heading:SetText(title)
    local divider = page:CreateTexture(nil, "ARTWORK")
    divider:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -6)
    divider:SetPoint("RIGHT", page, "RIGHT", 0, 0)
    divider:SetHeight(1)
    divider:SetColorTexture(unpack(self:GetStyle("window").header.divider))
    page.sectionDividers[#page.sectionDividers + 1] = divider
    return heading, offset + 30
end

local function RoundValue(value, decimals)
    local factor = 10 ^ decimals
    if value >= 0 then return math.floor(value * factor + 0.5) / factor end
    return math.ceil(value * factor - 0.5) / factor
end

local function CopyTable(source)
    local result = {}
    for key, value in pairs(source or {}) do result[key] = value end
    return result
end

local function ResolveOptionValues(values)
    if type(values) == "function" then values = values() end
    return type(values) == "table" and values or {}
end

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

local function SetViewEnabled(view, enabled)
    for i = 1, #view.controls do
        local control = view.controls[i]
        control:SetEnabled(enabled)
        control:SetAlpha(enabled and 1 or 0.35)
    end
    for i = 1, #view.valueLabels do
        view.valueLabels[i]:SetAlpha(enabled and 1 or 0.35)
    end
end

local function CommitValues(view, values)
    if not view.context or type(values) ~= "table" then return false end
    if view.definition.set(view.context, CopyTable(values)) == true then
        if view.context.id and NSkin.NotifySkinningElementBoundsChanged then
            NSkin:NotifySkinningElementBoundsChanged(view.context.id)
        end
        NSkin:NotifyOptionGroupChanged(view.id)
        return true
    end
    view:Refresh()
    return false
end

local function ResetValues(view)
    if not view.context then return false end
    if view.definition.reset(view.context) == true then
        NSkin:NotifyOptionGroupChanged(view.id)
        return true
    end
    view:Refresh()
    return false
end

local function CreateDropdown(view, control, y)
    local label = view:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("TOPLEFT", view, "TOPLEFT", 0, y)
    label:SetText(control.label)

    local dropdown = CreateOwnedDropdown(view)
    dropdown:SetSize(view.presentation == "FULL" and 220 or 202, 24)
    SkinAddonDropdown(dropdown)
    dropdown:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -4)
    dropdown:SetDefaultText(control.label)
    dropdown:SetupMenu(function(_, rootDescription)
        local choices = ResolveOptionValues(control.values)
        ConfigureDropdownMenuScroll(rootDescription, choices)
        local filter = AddDropdownMenuSearch(dropdown, rootDescription, choices)
        for i = 1, #choices do
            local choice = choices[i]
            if DropdownChoiceMatches(choice, filter) and choice.divider then
                if rootDescription.CreateDivider then rootDescription:CreateDivider() end
            elseif DropdownChoiceMatches(choice, filter) and choice.title then
                if rootDescription.CreateTitle then rootDescription:CreateTitle(choice.title) end
            elseif DropdownChoiceMatches(choice, filter) then
            local description = rootDescription:CreateRadio(
                choice.label,
                function(value)
                    if not view.context then return false end
                    local current = view.definition.get(view.context)
                    return current and current[control.key] == value
                end,
                function(value)
                    if not view.context then return end
                    local current = CopyTable(view.definition.get(view.context))
                    current[control.key] = value
                    CommitValues(view, current)
                end,
                choice.value
            )
            if type(choice.isEnabled) == "function"
                and description and description.SetEnabled
            then
                description:SetEnabled(choice.isEnabled(view.context) == true)
            end
            end
        end
    end)
    view.controls[#view.controls + 1] = dropdown
    view.controlByKey[control.key] = dropdown
    return 64
end

local function CreateSlider(view, control, y)
    local label = view:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("TOPLEFT", view, "TOPLEFT", 0, y)
    label:SetText(control.label)
    local valueLabel = CreateFrame("EditBox", nil, view)
    valueLabel:SetSize(58, 22)
    valueLabel:SetPoint("TOPRIGHT", view, "TOPRIGHT", 0, y + 4)
    valueLabel:SetAutoFocus(false)
    valueLabel:SetJustifyH("CENTER")
    valueLabel:SetFontObject(GameFontHighlightSmall)
    valueLabel:SetTextInsets(4, 4, 0, 0)
    NSkin:CreateFlatBackground(valueLabel, "NSkinSliderValue",
        NSkin:GetStyle("button").background, NSkin:GetSharedBorderColor())
    NSkin:SetPixelBorderSize(
        NSkin:GetPixelBorder(valueLabel, "NSkinSliderValueBorder"), 1)
    valueLabel:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
    view.valueLabels[#view.valueLabels + 1] = valueLabel

    local slider = NSkin:CreateOptionsSlider(view, {
        width = view.presentation == "FULL" and 280 or 202,
        min = control.min,
        max = control.max,
        step = control.step,
        onValueChanged = function(_, value)
            local decimals = tonumber(control.decimals) or 0
            value = RoundValue(value, decimals)
            valueLabel:SetText(string.format("%." .. decimals .. "f", value))
        end,
        onValueCommitted = function(_, value)
            local decimals = tonumber(control.decimals) or 0
            value = RoundValue(value, decimals)
            if view.refreshing or not view.context then return end
            local current = CopyTable(view.definition.get(view.context))
            current[control.key] = value
            CommitValues(view, current)
        end,
    })
    slider:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 8, -18)
    valueLabel:SetScript("OnEnterPressed", function(self)
        if not view.context then return end
        local value = math.max(control.min, math.min(control.max,
            tonumber(self:GetText()) or slider:GetValue()))
        value = RoundValue(value, tonumber(control.decimals) or 0)
        local current = CopyTable(view.definition.get(view.context))
        current[control.key] = value
        CommitValues(view, current)
        self:ClearFocus()
    end)
    valueLabel:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        view:Refresh()
    end)
    view.controls[#view.controls + 1] = slider
    view.controls[#view.controls + 1] = valueLabel
    view.controlByKey[control.key] = slider
    view.valueByKey[control.key] = valueLabel
    return 70
end

local function CreateOwnedCheckbox(parent)
    local checkbox = CreateFrame("CheckButton", nil, parent)
    checkbox:SetSize(22, 22)
    NSkin:CreateFlatBackground(checkbox, "NSkinOptionsCheckbox",
        NSkin:GetStyle("button").background, NSkin:GetSharedBorderColor())
    NSkin:SetPixelBorderSize(NSkin:GetPixelBorder(checkbox,
        "NSkinOptionsCheckboxBorder"), 1)
    local checked = checkbox:CreateTexture(nil, "ARTWORK")
    checked:SetPoint("TOPLEFT", checkbox, "TOPLEFT", 4, -4)
    checked:SetPoint("BOTTOMRIGHT", checkbox, "BOTTOMRIGHT", -4, 4)
    checked:SetColorTexture(unpack(NSkin:GetAccentColor()))
    checkbox:SetCheckedTexture(checked)
    local highlight = checkbox:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetPoint("TOPLEFT", checkbox, "TOPLEFT", 2, -2)
    highlight:SetPoint("BOTTOMRIGHT", checkbox, "BOTTOMRIGHT", -2, 2)
    highlight:SetColorTexture(1, 1, 1, 0.12)
    checkbox:SetHighlightTexture(highlight)
    checkbox.Text = checkbox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    checkbox.Text:SetPoint("LEFT", checkbox, "RIGHT", 7, 0)
    checkbox.Text:SetJustifyH("LEFT")
    checkbox.Text:SetJustifyV("MIDDLE")
    return checkbox
end

function NSkin:CreateOwnedOptionsCheckbox(parent)
    return CreateOwnedCheckbox(parent)
end

local function CreateCheckbox(view, control, y)
    local checkbox = CreateOwnedCheckbox(view)
    checkbox:SetPoint("TOPLEFT", view, "TOPLEFT", -4, y)
    if checkbox.Text then checkbox.Text:SetText(control.label) end
    checkbox:SetScript("OnClick", function(self)
        if view.refreshing or not view.context then return end
        local current = CopyTable(view.definition.get(view.context))
        current[control.key] = self:GetChecked() == true
        CommitValues(view, current)
    end)
    view.controls[#view.controls + 1] = checkbox
    view.controlByKey[control.key] = checkbox
    return 42
end

local function CreateDropdownPairItem(view, control, x, width, y, mirrored)
    if not control then return end
    local labelWidth = view.presentation == "COMPACT"
        and COMPACT_GRID_LABEL_WIDTH or (tonumber(control.labelWidth) or 70)
    local label = view:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint(mirrored and "RIGHT" or "LEFT", view, "TOPLEFT",
        mirrored and (x + width) or x, y)
    label:SetSize(math.max(1, labelWidth), COMPACT_GRID_HEIGHT - 8)
    label:SetWordWrap(true)
    label:SetJustifyH(view.presentation == "COMPACT" and "CENTER"
        or (mirrored and "RIGHT" or "LEFT"))
    label:SetJustifyV("MIDDLE")
    label:SetText(control.label)
    AddCompactGridControlDivider(view, label, mirrored)
    local dropdown = CreateOwnedDropdown(view)
    local dropdownReduction = control.dropdownReduction
    if dropdownReduction == nil then
        dropdownReduction = view.presentation == "COMPACT" and 10 or 0
    end
    dropdown:SetSize(width - labelWidth - dropdownReduction,
        view.presentation == "COMPACT" and 26 or 24)
    SkinAddonDropdown(dropdown)
    if mirrored then
        dropdown:SetPoint("LEFT", view, "TOPLEFT",
            x + dropdownReduction / 2, y)
    else
        dropdown:SetPoint("LEFT", view, "TOPLEFT",
            x + labelWidth + dropdownReduction / 2, y)
    end
    dropdown:SetDefaultText(control.label)
    dropdown:SetupMenu(function(_, rootDescription)
        local choices = ResolveOptionValues(control.values)
        ConfigureDropdownMenuScroll(rootDescription, choices)
        local filter = AddDropdownMenuSearch(dropdown, rootDescription, choices)
        for i = 1, #choices do
            local choice = choices[i]
            if DropdownChoiceMatches(choice, filter) and choice.divider then
                if rootDescription.CreateDivider then rootDescription:CreateDivider() end
            elseif DropdownChoiceMatches(choice, filter) then
                local description = rootDescription:CreateRadio(choice.label,
                    function(value)
                        local current = view.context and view.definition.get(view.context)
                        return current and current[control.key] == value
                    end,
                    function(value)
                        if not view.context then return end
                        local current = CopyTable(view.definition.get(view.context))
                        current[control.key] = value
                        CommitValues(view, current)
                    end, choice.value)
                if type(choice.isEnabled) == "function"
                    and description and description.SetEnabled
                then
                    description:SetEnabled(choice.isEnabled(view.context) == true)
                end
            end
        end
    end)
    view.controls[#view.controls + 1] = dropdown
    view.controlByKey[control.key] = dropdown
end

local function CreateTwoColumnGridRow(view, y, height, requestedGap)
    local gap = requestedGap == nil and COMPACT_GRID_CENTER_WIDTH
        or (tonumber(requestedGap) or 0)
    gap = NSkin:SnapToPhysicalPixel(view, gap)
    height = NSkin:SnapToPhysicalPixel(view, height)
    y = NSkin:SnapToPhysicalPixel(view, y)
    local width = NSkin:SnapToPhysicalPixel(view,
        (view:GetWidth() - gap) / 2)
    local row = CreateFrame("Frame", nil, view)
    row:SetPoint("TOPLEFT", view, "TOPLEFT", 0, y)
    row:SetSize(view:GetWidth(), height)
    row.left = CreateFrame("Frame", nil, row)
    row.left:SetPoint("TOPLEFT")
    row.left:SetSize(width, height)
    AddCompactGridCellBorder(row.left)
    row.right = CreateFrame("Frame", nil, row)
    row.right:SetPoint("TOPLEFT", row, "TOPLEFT", width + gap, 0)
    row.right:SetSize(width, height)
    AddCompactGridCellBorder(row.right)
    view.gridRows = view.gridRows or {}
    view.gridRows[#view.gridRows + 1] = row
    return width, gap, row
end

local function CreateDropdownReset(view, control, y)
    local labelWidth = tonumber(control.labelWidth) or 100
    local dropdownWidth = tonumber(control.dropdownWidth) or 101
    local width, gap
    if view.presentation == "COMPACT" then
        width, gap = CreateTwoColumnGridRow(view, y, COMPACT_GRID_HEIGHT)
    end
    CreateDropdownPairItem(view, control, COMPACT_GRID_PADDING,
        view.presentation == "COMPACT" and (width - COMPACT_GRID_PADDING * 2)
            or (labelWidth + dropdownWidth), y - 24)

    local reset = CreateFrame("Button", nil, view)
    reset:SetSize(24, 24)
    if view.presentation == "COMPACT" then
        reset:SetPoint("CENTER", view, "TOPLEFT", width + gap / 2, y - 24)
    else
        reset:SetPoint("LEFT", view, "TOPLEFT",
            COMPACT_GRID_PADDING + labelWidth + dropdownWidth + 6, y - 24)
    end
    local icon = reset:CreateTexture(nil, "ARTWORK")
    icon:SetSize(16, 16)
    icon:SetPoint("CENTER")
    icon:SetTexture(control.resetIcon)
    reset:SetScript("OnClick", function()
        if view.refreshing then return end
        ResetValues(view)
    end)
    reset:SetScript("OnEnter", function(self)
        icon:SetVertexColor(unpack(NSkin:GetAccentColor()))
        if control.resetTooltip and GameTooltip then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(control.resetTooltip)
            GameTooltip:Show()
        end
    end)
    reset:SetScript("OnLeave", function()
        icon:SetVertexColor(1, 1, 1, 1)
        if GameTooltip then GameTooltip:Hide() end
    end)
    view.controls[#view.controls + 1] = reset
    return COMPACT_GRID_HEIGHT - 1
end

local function CreateDropdownPair(view, control, y)
    local width, gap = CreateTwoColumnGridRow(view, y, COMPACT_GRID_HEIGHT)
    CreateDropdownPairItem(view, control.left, COMPACT_GRID_PADDING,
        width - COMPACT_GRID_PADDING * 2, y - 24)
    CreateDropdownPairItem(view, control.right, width + gap + COMPACT_GRID_PADDING,
        width - COMPACT_GRID_PADDING * 2, y - 24, true)
    return COMPACT_GRID_HEIGHT - 1
end

local function CreateControlPairItem(view, control, x, width, y, mirrored)
    if not control then return end
    if control.type == "DROPDOWN" then
        CreateDropdownPairItem(view, control, x, width, y, mirrored)
    elseif control.type == "CHECKBOX" then
        local checkbox = CreateOwnedCheckbox(view)
        checkbox:SetSize(24, 24)
        local label = view:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        label:SetSize(math.max(1, width - 40), COMPACT_GRID_HEIGHT - 8)
        label:SetWordWrap(true)
        if label.SetNonSpaceWrap then label:SetNonSpaceWrap(true) end
        label:SetJustifyH("CENTER")
        label:SetJustifyV("MIDDLE")
        label:SetText(control.label)
        if mirrored then
            checkbox:SetPoint("LEFT", view, "TOPLEFT", x, y)
            label:SetPoint("RIGHT", view, "TOPLEFT", x + width, y)
        else
            checkbox:SetPoint("RIGHT", view, "TOPLEFT", x + width, y)
            label:SetPoint("LEFT", view, "TOPLEFT", x, y)
        end
        if checkbox.Text then checkbox.Text:SetText("") end
        checkbox:SetScript("OnClick", function(self)
            if view.refreshing or not view.context then return end
            local current = CopyTable(view.definition.get(view.context))
            current[control.key] = self:GetChecked() == true
            CommitValues(view, current)
        end)
        view.controls[#view.controls + 1] = checkbox
        view.controlByKey[control.key] = checkbox
    end
end

local function CreateControlPair(view, control, y)
    local width, gap = CreateTwoColumnGridRow(view, y, COMPACT_GRID_HEIGHT)
    CreateControlPairItem(view, control.left, COMPACT_GRID_PADDING,
        width - COMPACT_GRID_PADDING * 2, y - 24)
    CreateControlPairItem(view, control.right, width + gap + COMPACT_GRID_PADDING,
        width - COMPACT_GRID_PADDING * 2, y - 24, true)
    return COMPACT_GRID_HEIGHT - 1
end

local function CreateTypographyDropdown(view, control, key, values, width, x, y, inline, mirrored)
    local label = view:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    if inline then
        label:SetPoint(mirrored and "RIGHT" or "LEFT", view, "TOPLEFT",
            mirrored and (x + width) or x, y - COMPACT_GRID_HEIGHT / 2)
        label:SetSize(COMPACT_GRID_LABEL_WIDTH, COMPACT_GRID_HEIGHT - 8)
        label:SetJustifyH("CENTER")
        label:SetJustifyV("MIDDLE")
    else
        label:SetPoint("TOPLEFT", view, "TOPLEFT", x, y)
    end
    label:SetText(control[key .. "Label"])
    if inline then AddCompactGridControlDivider(view, label, mirrored) end
    local dropdown = CreateOwnedDropdown(view)
    local labelWidth = inline and COMPACT_GRID_LABEL_WIDTH or 0
    dropdown:SetSize(width - labelWidth
        - (view.presentation == "COMPACT" and 10 or 0),
        view.presentation == "COMPACT" and 26 or 24)
    SkinAddonDropdown(dropdown)
    if inline then
        dropdown:SetPoint("LEFT", view, "TOPLEFT",
            mirrored and (x + (view.presentation == "COMPACT" and 5 or 0))
                or (x + labelWidth
                    + (view.presentation == "COMPACT" and 5 or 0)),
            y - COMPACT_GRID_HEIGHT / 2)
    else
        dropdown:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -3)
    end
    dropdown:SetDefaultText(control[key .. "Label"])
    dropdown:SetupMenu(function(_, rootDescription)
        local choices = ResolveOptionValues(values)
        ConfigureDropdownMenuScroll(rootDescription, choices)
        local filter = AddDropdownMenuSearch(dropdown, rootDescription, choices)
        for i = 1, #choices do
            local choice = choices[i]
            if DropdownChoiceMatches(choice, filter) and choice.divider then
                if rootDescription.CreateDivider then rootDescription:CreateDivider() end
            elseif DropdownChoiceMatches(choice, filter) and choice.title then
                if rootDescription.CreateTitle then rootDescription:CreateTitle(choice.title) end
            elseif DropdownChoiceMatches(choice, filter) then
                rootDescription:CreateRadio(choice.label,
                    function(value)
                        if not view.context then return false end
                        local current = view.definition.get(view.context)
                        return current and current[control[key .. "Key"]] == value
                    end,
                    function(value)
                        if not view.context then return end
                        local current = CopyTable(view.definition.get(view.context))
                        current[control[key .. "Key"]] = value
                        CommitValues(view, current)
                    end,
                    choice.value)
            end
        end
    end)
    view.controls[#view.controls + 1] = dropdown
    return { dropdown = dropdown, key = control[key .. "Key"], values = values,
        defaultLabel = control[key .. "Label"] }
end

local CreateColor

local function CreateTypographySizeSlider(view, control, parent)
    local definition = { key = control.sizeKey, label = control.sizeLabel,
        min = control.sizeMin or 8, max = control.sizeMax or 32,
        step = control.sizeStep or 1, decimals = 0 }
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("LEFT", parent, "LEFT", COMPACT_GRID_PADDING, 0)
    label:SetSize(COMPACT_GRID_LABEL_WIDTH, COMPACT_GRID_HEIGHT - 8)
    label:SetWordWrap(true)
    label:SetJustifyH("CENTER")
    label:SetJustifyV("MIDDLE")
    label:SetText(definition.label)
    AddCompactGridControlDivider(parent, label, false)
    local valueLabel = CreateFrame("EditBox", nil, parent)
    valueLabel:SetSize(38, 22)
    local labelDelta = COMPACT_GRID_LABEL_WIDTH - 56
    valueLabel:SetPoint("LEFT", parent, "LEFT", 70 + labelDelta, 0)
    valueLabel:SetAutoFocus(false)
    valueLabel:SetJustifyH("CENTER")
    valueLabel:SetFontObject(GameFontHighlightSmall)
    valueLabel:SetTextInsets(1, 1, 0, 0)
    NSkin:CreateFlatBackground(valueLabel, "NSkinSliderValue",
        NSkin:GetStyle("button").background, NSkin:GetSharedBorderColor())
    NSkin:SetPixelBorderSize(
        NSkin:GetPixelBorder(valueLabel, "NSkinSliderValueBorder"), 1)
    valueLabel:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
    local slider = NSkin:CreateOptionsSlider(parent, {
        width = parent:GetWidth() - 124 - labelDelta,
        min = definition.min, max = definition.max,
        step = definition.step,
        onValueChanged = function(_, value)
            value = RoundValue(value, 0)
            valueLabel:SetText(string.format("%.0f", value))
        end,
        onValueCommitted = function(_, value)
            value = RoundValue(value, 0)
            if view.refreshing or not view.context then return end
            local current = CopyTable(view.definition.get(view.context))
            current[definition.key] = value
            CommitValues(view, current)
        end,
    })
    slider:SetPoint("LEFT", parent, "LEFT", 116 + labelDelta, 0)
    valueLabel:SetScript("OnEnterPressed", function(self)
        if not view.context then return end
        local value = math.max(definition.min, math.min(definition.max,
            tonumber(self:GetText()) or slider:GetValue()))
        value = RoundValue(value, 0)
        local current = CopyTable(view.definition.get(view.context))
        current[definition.key] = value
        CommitValues(view, current)
        self:ClearFocus()
    end)
    valueLabel:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        view:Refresh()
    end)
    view.controls[#view.controls + 1] = slider
    view.controls[#view.controls + 1] = valueLabel
    view.controlByKey[definition.key] = slider
    view.valueByKey[definition.key] = valueLabel
    return { slider = slider, valueLabel = valueLabel, key = definition.key }
end

local function CreateTypography(view, control, y)
    local divider
    local rowY = y
    if not control.hideHeading then
        local heading = view:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        heading:SetPoint("TOPLEFT", view, "TOPLEFT", 0, y)
        heading:SetText(control.label)
        divider = view:CreateTexture(nil, "ARTWORK")
        divider:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -5)
        divider:SetPoint("RIGHT", view, "RIGHT", 0, 0)
        divider:SetHeight(1)
        divider:SetColorTexture(unpack(NSkin:GetStyle("window").header.divider))
        rowY = y - 24
    end
    local width, gap = CreateTwoColumnGridRow(view, rowY, COMPACT_GRID_HEIGHT)
    local rowStep = COMPACT_GRID_HEIGHT - 1
    local _, _, secondRow = CreateTwoColumnGridRow(
        view, rowY - rowStep, COMPACT_GRID_HEIGHT)
    local font = CreateTypographyDropdown(view, control, "font", control.fontValues,
        width - COMPACT_GRID_PADDING * 2, COMPACT_GRID_PADDING, rowY, true)
    local outline = CreateTypographyDropdown(view, control, "outline",
        control.outlineValues, width - COMPACT_GRID_PADDING * 2,
        width + gap + COMPACT_GRID_PADDING, rowY, true, true)
    local size = CreateTypographySizeSlider(view, control, secondRow.left)
    if control.color then
        CreateColor(view, control.color, rowY - rowStep,
            { x = width + gap + COMPACT_GRID_PADDING,
                width = width - COMPACT_GRID_PADDING * 2, inline = true,
                mirrored = true })
    end
    local row = {
        controls = { font, outline }, size = size, divider = divider,
    }
    view.typographyRows[#view.typographyRows + 1] = row
    view.typographyByControl[control] = row
    return control.hideHeading and 94 or 118
end

local function ResolveColorModeFill(values, control, mode)
    if mode == "CLASS" then
        local _, class = UnitClass("player")
        local classColor = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
        if classColor then
            return { classColor.r, classColor.g, classColor.b, 1 }
        end
        return { 1, 1, 1, 1 }
    elseif mode == "ACCENT" then
        return NSkin:GetAccentColor()
    end
    local custom = values and values[control.key]
    return type(custom) == "table" and custom or { 1, 1, 1, 1 }
end

local function FillColorDropdown(dropdown, color)
    local background = NSkin:CreateFlatBackground(dropdown, "NSkinOptionsDropdown",
        color, NSkin:GetSharedBorderColor())
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
end

local function FillColorDropdownChoice(button, color)
    if not button then return end
    if button.indicator then
        NSkin:SetPixelBorderShown(NSkin:GetPixelBorder(button.indicator,
            "NSkinOwnedDropdownCheckboxBorder"), false)
    end
    local fill = button.nskinColorFill
    if not fill then
        if button.nskinOwnedMenuRow and button.CreateTexture then
            fill = button:CreateTexture(nil, "ARTWORK", nil, -8)
            button.nskinColorFill = fill
        elseif button.AttachTexture then
            fill = button:AttachTexture()
        end
    end
    if not fill then return end
    fill:SetDrawLayer("ARTWORK", -8)
    fill:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1)
    fill:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
    fill:SetColorTexture(unpack(color))
    fill:SetAlpha(1)
    fill:Show()
end

CreateColor = function(view, control, y, layout)
    layout = layout or {}
    local x = tonumber(layout.x) or 0
    local width = tonumber(layout.width) or view:GetWidth()
    local inlineLabelWidth = layout.inline and COMPACT_GRID_LABEL_WIDTH or 0
    local hasColorMode = type(control.modeKey) == "string"
    local label = view:CreateFontString(nil, "OVERLAY",
        layout.inline and "GameFontNormalSmall" or "GameFontNormal")
    if layout.inline then
        label:SetPoint(layout.mirrored and "RIGHT" or "LEFT", view, "TOPLEFT",
            layout.mirrored and (x + width) or x,
            y - COMPACT_GRID_HEIGHT / 2)
        label:SetSize(inlineLabelWidth, COMPACT_GRID_HEIGHT - 8)
        label:SetWordWrap(true)
        label:SetJustifyH("CENTER")
        label:SetJustifyV("MIDDLE")
    else
        label:SetPoint("TOPLEFT", view, "TOPLEFT", x, y - 6)
    end
    label:SetText(control.label)
    if layout.inline then
        AddCompactGridControlDivider(view, label, layout.mirrored)
    end
    local dropdown = CreateOwnedDropdown(view)
    local controlWidth = math.max(80, width - inlineLabelWidth - 10)
    dropdown:SetSize(math.min(controlWidth,
        view.presentation == "FULL" and 180 or 150),
        view.presentation == "COMPACT" and 26 or 24)
    SkinAddonDropdown(dropdown)
    if layout.inline then
        local controlLeft = layout.mirrored and x or (x + inlineLabelWidth)
        dropdown:SetPoint("LEFT", view, "TOPLEFT",
            math.floor(controlLeft
                + (math.max(dropdown:GetWidth(), width - inlineLabelWidth)
                    - dropdown:GetWidth()) / 2 + 0.5),
            y - COMPACT_GRID_HEIGHT / 2)
    else
        dropdown:SetPoint("TOPRIGHT", view, "TOPLEFT", x + width, y - 3)
    end

    local function OpenCustomColorPicker(previousMode)
        if not view.context then return end
        local current = view.definition.get(view.context)
        local previous = current and current[control.key]
        if type(previous) ~= "table" then return end
        previous = { previous[1], previous[2], previous[3], previous[4] or 1 }

        local function ApplyPickerColor(color)
            if not view.context then return end
            local red, green, blue = ColorPickerFrame:GetColorRGB()
            local values = CopyTable(view.definition.get(view.context))
            values[control.key] = color or { red, green, blue, previous[4] }
            if hasColorMode then
                values[control.modeKey] = color and previousMode or "CUSTOM"
            end
            CommitValues(view, values)
        end
        ColorPickerFrame:SetupColorPickerAndShow({
            r = previous[1],
            g = previous[2],
            b = previous[3],
            swatchFunc = ApplyPickerColor,
            cancelFunc = function() ApplyPickerColor(previous) end,
        })
    end

    dropdown:SetDefaultText("Custom")
    dropdown:SetupMenu(function(_, rootDescription)
        local current = view.context and view.definition.get(view.context)
        local previousMode = hasColorMode and current and current[control.modeKey]
        local modes = hasColorMode and {
            { value = "CLASS", label = "Class" },
            { value = "ACCENT", label = "Accent" },
            { value = "CUSTOM", label = "Custom" },
        } or {
            { value = "CUSTOM", label = "Custom" },
        }
        for i = 1, #modes do
            local mode = modes[i]
            local description = rootDescription:CreateRadio(mode.label,
                function(value)
                    if not hasColorMode then return value == "CUSTOM" end
                    local values = view.context
                        and view.definition.get(view.context)
                    return values and values[control.modeKey] == value
                end,
                function(value)
                    if value == "CUSTOM" then
                        OpenCustomColorPicker(previousMode)
                    elseif view.context then
                        local values = CopyTable(view.definition.get(view.context))
                        values[control.modeKey] = value
                        CommitValues(view, values)
                    end
                end, mode.value)
            if description and description.AddInitializer then
                local fill = ResolveColorModeFill(current, control, mode.value)
                description:AddInitializer(function(button)
                    FillColorDropdownChoice(button, fill)
                end)
            end
        end
    end)

    view.controls[#view.controls + 1] = dropdown
    view.controlByKey[control.key] = dropdown
    view.colorByKey[control.key] = dropdown
    view.colorDefinitionByKey[control.key] = control
    if hasColorMode then
        view.colorModeByKey[control.key] = control.modeKey
    end
    return 38
end

local function RefreshColorControl(view, control, values)
    local value = values and values[control.key]
    if type(value) ~= "table" then return end
    local dropdown = view.colorByKey[control.key]
    local modeKey = view.colorModeByKey[control.key]
    local mode = modeKey and values[modeKey] or "CUSTOM"
    local labels = { CLASS = "Class", ACCENT = "Accent", CUSTOM = "Custom" }
    FillColorDropdown(dropdown, ResolveColorModeFill(values, control, mode))
    dropdown:SetDefaultText(labels[mode] or "Custom")
    if dropdown.GenerateMenu then dropdown:GenerateMenu() end
end

local function CreateSection(view, control, y)
    local heading = view:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    heading:SetPoint("TOPLEFT", view, "TOPLEFT", 0, y)
    heading:SetText(control.label)
    local divider = view:CreateTexture(nil, "ARTWORK")
    divider:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -5)
    divider:SetPoint("RIGHT", view, "RIGHT", 0, 0)
    divider:SetHeight(1)
    divider:SetColorTexture(unpack(NSkin:GetStyle("window").header.divider))
    view.sectionDividers[#view.sectionDividers + 1] = divider
    return 30
end

local function CreateColorPair(view, control, y)
    local width, gap = CreateTwoColumnGridRow(view, y, COMPACT_GRID_HEIGHT)
    if control.left then
        CreateColor(view, control.left, y, { x = COMPACT_GRID_PADDING,
            width = width - COMPACT_GRID_PADDING * 2, inline = true })
    end
    if control.right then
        CreateColor(view, control.right, y,
            { x = width + gap + COMPACT_GRID_PADDING,
                width = width - COMPACT_GRID_PADDING * 2, inline = true,
                mirrored = true })
    end
    return COMPACT_GRID_HEIGHT - 1
end

local function CreateSliderPairItem(view, definition, x, width, y, mirroredSide, cell)
    local parent = cell or view
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    if mirroredSide == "RIGHT" then
        label:SetPoint("RIGHT", parent, "RIGHT", -COMPACT_GRID_PADDING, 0)
        label:SetSize(COMPACT_GRID_LABEL_WIDTH, COMPACT_GRID_HEIGHT - 8)
        label:SetWordWrap(true)
        if label.SetNonSpaceWrap then label:SetNonSpaceWrap(true) end
        label:SetJustifyH("CENTER")
        label:SetJustifyV("MIDDLE")
    elseif mirroredSide == "LEFT" then
        label:SetPoint("LEFT", parent, "LEFT", COMPACT_GRID_PADDING, 0)
        label:SetSize(COMPACT_GRID_LABEL_WIDTH, COMPACT_GRID_HEIGHT - 8)
        label:SetWordWrap(true)
        if label.SetNonSpaceWrap then label:SetNonSpaceWrap(true) end
        label:SetJustifyH("CENTER")
        label:SetJustifyV("MIDDLE")
    else
        label:SetPoint("LEFT", view, "TOPLEFT", x, y)
        label:SetSize(64, COMPACT_GRID_HEIGHT - 8)
        label:SetWordWrap(true)
        label:SetJustifyH("LEFT")
        label:SetJustifyV("MIDDLE")
    end
    label:SetText(definition.label)
    if mirroredSide then
        AddCompactGridControlDivider(parent, label, mirroredSide == "RIGHT")
    end
    local valueLabel = CreateFrame("EditBox", nil, parent)
    valueLabel:SetSize(38, 22)
    valueLabel:SetAutoFocus(false)
    valueLabel:SetJustifyH("CENTER")
    valueLabel:SetFontObject(GameFontHighlightSmall)
    valueLabel:SetTextInsets(1, 1, 0, 0)
    NSkin:CreateFlatBackground(valueLabel, "NSkinSliderValue",
        NSkin:GetStyle("button").background, NSkin:GetSharedBorderColor())
    NSkin:SetPixelBorderSize(
        NSkin:GetPixelBorder(valueLabel, "NSkinSliderValueBorder"), 1)
    valueLabel:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
    view.valueLabels[#view.valueLabels + 1] = valueLabel
    local labelDelta = COMPACT_GRID_LABEL_WIDTH - 56
    local trackWidth = width
        - (mirroredSide and 124 or 118) - labelDelta
    local slider = NSkin:CreateOptionsSlider(parent, {
        width = trackWidth, min = definition.min, max = definition.max,
        step = definition.step,
        onValueChanged = function(_, value)
            local decimals = tonumber(definition.decimals) or 0
            value = RoundValue(value, decimals)
            valueLabel:SetText(string.format("%." .. decimals .. "f", value))
        end,
        onValueCommitted = function(_, value)
            local decimals = tonumber(definition.decimals) or 0
            value = RoundValue(value, decimals)
            if view.refreshing or not view.context then return end
            local current = CopyTable(view.definition.get(view.context))
            current[definition.key] = value
            CommitValues(view, current)
        end,
    })
    if mirroredSide == "LEFT" then
        valueLabel:SetPoint("LEFT", parent, "LEFT", 70 + labelDelta, 0)
        slider:SetPoint("LEFT", parent, "LEFT", 116 + labelDelta, 0)
    elseif mirroredSide == "RIGHT" then
        slider:SetPoint("LEFT", parent, "LEFT", COMPACT_GRID_PADDING, 0)
        valueLabel:SetPoint("LEFT", parent, "LEFT", trackWidth + 16, 0)
    else
        valueLabel:SetPoint("RIGHT", view, "TOPLEFT", x + width, y)
        slider:SetPoint("LEFT", view, "TOPLEFT", x + 72, y)
    end
    valueLabel:SetScript("OnEnterPressed", function(self)
        if not view.context then return end
        local value = math.max(definition.min, math.min(definition.max,
            tonumber(self:GetText()) or slider:GetValue()))
        value = RoundValue(value, tonumber(definition.decimals) or 0)
        local current = CopyTable(view.definition.get(view.context))
        current[definition.key] = value
        CommitValues(view, current)
        self:ClearFocus()
    end)
    valueLabel:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        view:Refresh()
    end)
    view.controls[#view.controls + 1] = slider
    view.controls[#view.controls + 1] = valueLabel
    view.controlByKey[definition.key] = slider
    view.valueByKey[definition.key] = valueLabel
end

local function CreateSliderPair(view, control, y)
    if control.centerReset then
        local centerWidth = COMPACT_GRID_CENTER_WIDTH
        local width = math.floor((view:GetWidth() - centerWidth) / 2)
        local row = CreateFrame("Frame", nil, view)
        row:SetPoint("TOPLEFT", view, "TOPLEFT", 0, y)
        row:SetSize(view:GetWidth(), COMPACT_GRID_HEIGHT)
        local left = CreateFrame("Frame", nil, row)
        left:SetPoint("TOPLEFT")
        left:SetSize(width, COMPACT_GRID_HEIGHT)
        AddCompactGridCellBorder(left)
        local center = CreateFrame("Frame", nil, row)
        center:SetPoint("TOPLEFT", left, "TOPRIGHT", 0, 0)
        center:SetSize(centerWidth, COMPACT_GRID_HEIGHT)
        AddCompactGridCellBorder(center)
        local right = CreateFrame("Frame", nil, row)
        right:SetPoint("TOPLEFT", center, "TOPRIGHT", 0, 0)
        right:SetSize(width, COMPACT_GRID_HEIGHT)
        AddCompactGridCellBorder(right)
        CreateSliderPairItem(view, control.left, 0, width, 0, "LEFT", left)
        CreateSliderPairItem(view, control.right, 0, width, 0, "RIGHT", right)

        local reset = CreateFrame("Button", nil, center)
        reset:SetSize(24, 24)
        reset:SetPoint("CENTER")
        local icon = reset:CreateTexture(nil, "ARTWORK")
        icon:SetSize(16, 16)
        icon:SetPoint("CENTER")
        icon:SetTexture("Interface\\AddOns\\NSkin\\Media\\rotate-right.png")
        reset:SetScript("OnClick", function()
            if view.refreshing or not view.context then return end
            local values = CopyTable(view.definition.get(view.context))
            values[control.left.key] = control.left.resetValue or 0
            values[control.right.key] = control.right.resetValue or 0
            CommitValues(view, values)
        end)
        reset:SetScript("OnEnter", function(self)
            icon:SetVertexColor(unpack(NSkin:GetAccentColor()))
            if GameTooltip then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(control.resetTooltip or "Reset offsets")
                GameTooltip:Show()
            end
        end)
        reset:SetScript("OnLeave", function()
            icon:SetVertexColor(1, 1, 1, 1)
            if GameTooltip then GameTooltip:Hide() end
        end)
        view.controls[#view.controls + 1] = reset
    else
        local width, gap, row = CreateTwoColumnGridRow(view, y, COMPACT_GRID_HEIGHT)
        if control.left then
            CreateSliderPairItem(view, control.left, 0, width, 0,
                "LEFT", row.left)
        end
        if control.right then
            CreateSliderPairItem(view, control.right, 0, width, 0,
                "RIGHT", row.right)
        end
    end
    return COMPACT_GRID_HEIGHT - 1
end

local function CreateSliderDropdownPair(view, control, y)
    local width, gap, row = CreateTwoColumnGridRow(view, y, COMPACT_GRID_HEIGHT)
    if control.left then
        CreateSliderPairItem(view, control.left, 0, width, 0, "LEFT", row.left)
    end
    if control.right then
        CreateDropdownPairItem(view, control.right,
            width + gap + COMPACT_GRID_PADDING,
            width - COMPACT_GRID_PADDING * 2,
            y - COMPACT_GRID_HEIGHT / 2, true)
    end
    return COMPACT_GRID_HEIGHT - 1
end

local function CreateReset(view, control, y)
    local button = CreateFrame("Button", nil, view)
    if view.presentation == "COMPACT" then
        CreateTwoColumnGridRow(view, y, COMPACT_GRID_HEIGHT)
        button:SetSize(24, 24)
        button:SetPoint("TOP", view, "TOP", 0, y - 12)
        local icon = button:CreateTexture(nil, "ARTWORK")
        icon:SetSize(16, 16)
        icon:SetPoint("CENTER")
        icon:SetTexture("Interface\\AddOns\\NSkin\\Media\\rotate-right.png")
        button:SetScript("OnEnter", function(self)
            icon:SetVertexColor(unpack(NSkin:GetAccentColor()))
            if GameTooltip then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(control.label or "Reset")
                GameTooltip:Show()
            end
        end)
        button:SetScript("OnLeave", function()
            icon:SetVertexColor(1, 1, 1, 1)
            if GameTooltip then GameTooltip:Hide() end
        end)
    else
        button:SetSize(110, 24)
        button:SetPoint("TOP", view, "TOP", 0, y - 18)
        NSkin:SkinFlatButton(button, control.label or "Reset", nil, nil, 12)
    end
    button:SetScript("OnClick", function() ResetValues(view) end)
    view.controls[#view.controls + 1] = button
    view.resetButton = button
    view.resetControl = control
    return view.presentation == "COMPACT" and COMPACT_GRID_HEIGHT - 1 or 60
end

local function GetOrderedControls(definition)
    local controls = {}
    for i = 1, #definition.controls do
        local control = definition.controls[i]
        controls[i] = { definition = control, index = i }
    end
    table.sort(controls, function(a, b)
        local aOrder = a.definition.order
            or (a.definition.type == "RESET" and 100000 or a.index)
        local bOrder = b.definition.order
            or (b.definition.type == "RESET" and 100000 or b.index)
        if aOrder == bOrder then return a.index < b.index end
        return aOrder < bOrder
    end)
    return controls
end

function NSkin:RegisterOptionGroup(id, definition)
    if type(id) ~= "string" or id == ""
        or type(definition) ~= "table"
        or type(definition.controls) ~= "table"
        or type(definition.get) ~= "function"
        or type(definition.set) ~= "function"
        or type(definition.reset) ~= "function"
        or optionGroups[id]
    then
        return false
    end
    definition.orderedControls = GetOrderedControls(definition)
    optionGroups[id] = definition
    viewsByGroup[id] = setmetatable({}, { __mode = "k" })
    return true
end

function NSkin:RegisterOptionGroupSubset(id, sourceID, controls)
    local source = optionGroups[sourceID]
    if not source or type(controls) ~= "table" then return false end
    local keys = {}
    local function CollectKeys(control)
        if not control then return end
        for _, field in ipairs({ "key", "modeKey", "fontKey", "sizeKey", "outlineKey" }) do
            if type(control[field]) == "string" then keys[control[field]] = true end
        end
        CollectKeys(control.color)
        CollectKeys(control.left)
        CollectKeys(control.right)
    end
    local subsetControls = {}
    for i = 1, #controls do
        local control = controls[i]
        CollectKeys(control)
        if control.type == "TYPOGRAPHY" then
            local copy = {}
            for key, value in pairs(control) do copy[key] = value end
            copy.hideHeading = true
            control = copy
        end
        subsetControls[#subsetControls + 1] = control
    end
    return self:RegisterOptionGroup(id, {
        controls = subsetControls,
        inheritedReset = true,
        inheritedResetLabel = "Reset to window defaults",
        get = source.get,
        set = function(context, values)
            local filtered = {}
            for key in pairs(keys) do filtered[key] = values[key] end
            return source.set(context, filtered)
        end,
        reset = function(context)
            if type(source.resetSubset) == "function" then
                return source.resetSubset(context, keys)
            end
            return source.reset(context)
        end,
    })
end

function NSkin:GetOptionGroupDefinition(id)
    return optionGroups[id]
end

function NSkin:ResetOptionGroup(id, context)
    local definition = optionGroups[id]
    if not definition or not context then return false end
    if definition.reset(context) == true then
        self:NotifyOptionGroupChanged(id)
        return true
    end
    return false
end

function NSkin:CreateOptionGroupView(parent, id, layout, context)
    local definition = optionGroups[id]
    local presentation = layout == "COMPACT" and "COMPACT" or "FULL"
    if not parent or not definition then return nil end

    local view = CreateFrame("Frame", nil, parent)
    view:SetWidth(presentation == "FULL" and 400 or COMPACT_OPTIONS_WIDTH)
    view.id = id
    view.definition = definition
    view.presentation = presentation
    view.context = context
    view.controls = {}
    view.valueLabels = {}
    view.controlByKey = {}
    view.valueByKey = {}
    view.colorByKey = {}
    view.colorDefinitionByKey = {}
    view.colorModeByKey = {}
    view.typographyRows = {}
    view.typographyByControl = {}
    view.sectionDividers = {}

    local y = 0
    for i = 1, #definition.orderedControls do
        local control = definition.orderedControls[i].definition
        local height
        if control.type == "DROPDOWN" then
            height = presentation == "COMPACT"
                and CreateDropdownPair(view, { left = control }, y)
                or CreateDropdown(view, control, y)
        elseif control.type == "DROPDOWN_RESET" then
            height = CreateDropdownReset(view, control, y)
        elseif control.type == "DROPDOWN_PAIR" then
            height = CreateDropdownPair(view, control, y)
        elseif control.type == "CONTROL_PAIR" then
            height = CreateControlPair(view, control, y)
        elseif control.type == "SLIDER" then
            height = presentation == "COMPACT"
                and CreateSliderPair(view, { left = control }, y)
                or CreateSlider(view, control, y)
        elseif control.type == "CHECKBOX" then
            height = presentation == "COMPACT"
                and CreateControlPair(view, {
                    left = { type = "CHECKBOX", key = control.key,
                        label = control.label },
                }, y) or CreateCheckbox(view, control, y)
        elseif control.type == "COLOR" then
            height = presentation == "COMPACT"
                and CreateColorPair(view, { left = control }, y)
                or CreateColor(view, control, y)
        elseif control.type == "TYPOGRAPHY" then
            height = CreateTypography(view, control, y)
        elseif control.type == "SECTION" then
            height = CreateSection(view, control, y)
        elseif control.type == "COLOR_PAIR" then
            height = CreateColorPair(view, control, y)
        elseif control.type == "SLIDER_PAIR" then
            height = CreateSliderPair(view, control, y)
        elseif control.type == "SLIDER_DROPDOWN_PAIR" then
            height = CreateSliderDropdownPair(view, control, y)
        elseif control.type == "RESET" then
            height = CreateReset(view, control, y)
        end
        y = NSkin:SnapToPhysicalPixel(view, y - (height or 0))
    end
    view:SetHeight(NSkin:SnapToPhysicalPixel(view,
        math.max(1, -y + (presentation == "COMPACT" and 1 or 0))))

    function view:SetContext(newContext)
        self.context = newContext
        self:Refresh()
    end

    function view:SetValues(values)
        return CommitValues(self, values)
    end

    function view:SetPreviewValue(key, value, decimals)
        local slider, valueLabel = self.controlByKey[key], self.valueByKey[key]
        if not slider or not valueLabel or value == nil then return false end
        local wasRefreshing = self.refreshing
        self.refreshing = true
        slider:SetValue(value)
        valueLabel:SetText(string.format("%." .. (tonumber(decimals) or 0) .. "f", value))
        self.refreshing = wasRefreshing
        return true
    end

    function view:Refresh()
        local enabled = self.context ~= nil
        local values = enabled and self.definition.get(self.context) or nil
        self.refreshing = true
        for i = 1, #self.definition.orderedControls do
            local control = self.definition.orderedControls[i].definition
            local value = values and values[control.key]
            if control.type == "DROPDOWN" or control.type == "DROPDOWN_RESET" then
                local dropdown = self.controlByKey[control.key]
                local text = control.label
                local choices = ResolveOptionValues(control.values)
                for j = 1, #choices do
                    if choices[j].value == value then text = choices[j].label break end
                end
                dropdown:SetDefaultText(text)
                if dropdown.GenerateMenu then dropdown:GenerateMenu() end
            elseif control.type == "DROPDOWN_PAIR" then
                for _, definition in ipairs({ control.left, control.right }) do
                    if definition then
                        local selected = values and values[definition.key]
                        local text = definition.label
                        local choices = ResolveOptionValues(definition.values)
                        for j = 1, #choices do
                            if choices[j].value == selected then
                                text = choices[j].label
                                break
                            end
                        end
                        local dropdown = self.controlByKey[definition.key]
                        dropdown:SetDefaultText(text)
                        if dropdown.GenerateMenu then dropdown:GenerateMenu() end
                    end
                end
            elseif control.type == "CONTROL_PAIR" then
                for _, definition in ipairs({ control.left, control.right }) do
                    if definition then
                        local widget = self.controlByKey[definition.key]
                        if definition.type == "CHECKBOX" then
                            widget:SetChecked(values and values[definition.key] == true)
                        elseif definition.type == "DROPDOWN" then
                            local selected = values and values[definition.key]
                            local text = definition.label
                            local choices = ResolveOptionValues(definition.values)
                            for j = 1, #choices do
                                if choices[j].value == selected then
                                    text = choices[j].label
                                    break
                                end
                            end
                            widget:SetDefaultText(text)
                            if widget.GenerateMenu then widget:GenerateMenu() end
                        end
                    end
                end
            elseif control.type == "SLIDER" then
                if value ~= nil then self.controlByKey[control.key]:SetValue(value) end
                local decimals = tonumber(control.decimals) or 0
                self.valueByKey[control.key]:SetText(
                    value ~= nil and string.format("%." .. decimals .. "f", value) or "-"
                )
            elseif control.type == "CHECKBOX" then
                self.controlByKey[control.key]:SetChecked(value == true)
            elseif control.type == "COLOR" and type(value) == "table" then
                RefreshColorControl(self, control, values)
            elseif control.type == "COLOR_PAIR" then
                RefreshColorControl(self, control.left, values)
                RefreshColorControl(self, control.right, values)
            elseif control.type == "TYPOGRAPHY" then
                local row = self.typographyByControl[control]
                for j = 1, #row.controls do
                    local item = row.controls[j]
                    local selected = values and values[item.key]
                    local text = item.defaultLabel
                    local choices = ResolveOptionValues(item.values)
                    for k = 1, #choices do
                        if choices[k].value == selected then
                            text = choices[k].label
                            break
                        end
                    end
                    item.dropdown:SetDefaultText(text)
                    if item.dropdown.GenerateMenu then item.dropdown:GenerateMenu() end
                end
                local selectedSize = values and values[control.sizeKey]
                if selectedSize == "__NSKIN_GLOBAL__" then
                    selectedSize = NSkin:GetStyle("typography").size
                end
                selectedSize = tonumber(selectedSize)
                if selectedSize then
                    row.size.slider:SetValue(selectedSize)
                    row.size.valueLabel:SetText(string.format("%.0f", selectedSize))
                else
                    row.size.valueLabel:SetText("-")
                end
                if control.color then
                    RefreshColorControl(self, control.color, values)
                end
            elseif control.type == "SLIDER_PAIR" then
                for _, definition in ipairs({ control.left, control.right }) do
                    local selected = values and values[definition.key]
                    if selected ~= nil then
                        self.controlByKey[definition.key]:SetValue(selected)
                    end
                    local decimals = tonumber(definition.decimals) or 0
                    self.valueByKey[definition.key]:SetText(selected ~= nil
                        and string.format("%." .. decimals .. "f", selected) or "-")
                end
            elseif control.type == "SLIDER_DROPDOWN_PAIR" then
                local sliderDefinition, dropdownDefinition = control.left, control.right
                local selected = values and values[sliderDefinition.key]
                if selected ~= nil then
                    self.controlByKey[sliderDefinition.key]:SetValue(selected)
                end
                local decimals = tonumber(sliderDefinition.decimals) or 0
                self.valueByKey[sliderDefinition.key]:SetText(selected ~= nil
                    and string.format("%." .. decimals .. "f", selected) or "-")
                local dropdownValue = values and values[dropdownDefinition.key]
                local text = dropdownDefinition.label
                local choices = ResolveOptionValues(dropdownDefinition.values)
                for j = 1, #choices do
                    if choices[j].value == dropdownValue then
                        text = choices[j].label
                        break
                    end
                end
                local dropdown = self.controlByKey[dropdownDefinition.key]
                dropdown:SetDefaultText(text)
                if dropdown.GenerateMenu then dropdown:GenerateMenu() end
            end
        end
        self.refreshing = false
        SetViewEnabled(self, enabled)
    end

    function view:ApplyTheme()
        local values = self.context and self.definition.get(self.context)
        for key, dropdown in pairs(self.colorByKey) do
            local modeKey = self.colorModeByKey[key]
            local mode = modeKey and values and values[modeKey] or "CUSTOM"
            local control = self.colorDefinitionByKey[key]
            local labels = {
                CLASS = "Class", ACCENT = "Accent", CUSTOM = "Custom",
            }
            if control then
                FillColorDropdown(dropdown,
                    ResolveColorModeFill(values, control, mode))
            end
            dropdown:SetDefaultText(labels[mode] or "Custom")
            if dropdown.GenerateMenu then dropdown:GenerateMenu() end
        end
        local dividerColor = NSkin:GetStyle("window").header.divider
        for i = 1, #self.typographyRows do
            local divider = self.typographyRows[i].divider
            if divider then divider:SetColorTexture(unpack(dividerColor)) end
        end
        for i = 1, #self.sectionDividers do
            self.sectionDividers[i]:SetColorTexture(unpack(dividerColor))
        end
        if self.resetButton and self.presentation ~= "COMPACT" then
            NSkin:SkinFlatButton(self.resetButton,
                self.resetControl.label or "Reset", nil, nil, 12)
        end
    end

    viewsByGroup[id][view] = true
    view:Refresh()
    return view
end

function NSkin:NotifyOptionGroupChanged(id)
    local views = viewsByGroup[id]
    if not views then return false end
    for view in pairs(views) do
        if view.Refresh then view:Refresh() end
    end
    return true
end
