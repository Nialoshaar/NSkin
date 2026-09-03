local _, NSkin = ...

NSkin.pendingOptionsPages = NSkin.pendingOptionsPages or {}
function NSkin:RegisterOptionsPage(definition)
    if type(definition) ~= "table" or type(definition.builder) ~= "function" then
        return false
    end
    self.pendingOptionsPages[#self.pendingOptionsPages + 1] = definition
    return true
end

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

    function page:ApplyStructureAppearance()
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
            if control.resetGroup and type(view.definition.reset) == "function" then
                view.definition.reset(view.context)
                view:Refresh()
                return
            end
            if control.resetSubset
                and type(view.definition.resetSubset) == "function"
            then
                view.definition.resetSubset(view.context, {
                    [control.left.key] = true,
                    [control.right.key] = true,
                })
                view:Refresh()
                return
            end
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

    function view:ApplyAppearance()
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

do
local _, NSkin = ...

local function CopyColor(color)
    return { color[1], color[2], color[3], color[4] or 1 }
end

local function ColorsEqual(left, right)
    return left and right
        and left[1] == right[1] and left[2] == right[2]
        and left[3] == right[3] and (left[4] or 1) == (right[4] or 1)
end

local function ColorWithOpacity(color, opacity)
    return { color[1], color[2], color[3], tonumber(opacity) or color[4] or 1 }
end

local function SetColor(path, current, color, opacity)
    local value = ColorWithOpacity(color, opacity)
    if ColorsEqual(current, value) then return false end
    return NSkin:SetAppearanceOverride(path, value)
end

local function SetScalar(path, current, value)
    if value == nil or current == value then return false end
    return NSkin:SetAppearanceOverride(path, value)
end

local function ResetPaths(paths)
    local changed
    for i = 1, #paths do changed = NSkin:ResetAppearanceOverride(paths[i]) or changed end
    return changed == true
end

NSkin:RegisterOptionGroup("appearance.typography", {
    controls = {
        { type = "DROPDOWN", key = "font", label = "Global font",
            values = function() return NSkin:GetAvailableFontOptions(false) end },
        { type = "SLIDER", key = "size", label = "Global text size", min = 8,
            max = 32, step = 1, suffix = " px" },
        { type = "DROPDOWN", key = "outline", label = "Global outline", values = {
            { value = "", label = "None" },
            { value = "OUTLINE", label = "Outline" },
            { value = "THICKOUTLINE", label = "Thick outline" },
            { value = "MONOCHROME,OUTLINE", label = "Monochrome outline" },
        } },
        { type = "RESET", label = "Reset Typography" },
    },
    get = function()
        local style = NSkin:GetStyle("typography")
        return { font = style.font, size = style.size, outline = style.outline }
    end,
    set = function(_, values)
        local style = NSkin:GetStyle("typography")
        local changed = SetScalar("typography.font", style.font, values.font)
        changed = SetScalar("typography.size", style.size, values.size) or changed
        changed = SetScalar("typography.outline", style.outline, values.outline) or changed
        return changed == true
    end,
    reset = function()
        return ResetPaths({ "typography.font", "typography.size", "typography.outline" })
    end,
})

NSkin:RegisterOptionGroup("appearance.window", {
    controls = {
        { type = "COLOR", key = "backgroundColor", label = "Window background" },
        { type = "SLIDER", key = "backgroundOpacity", label = "Background opacity",
            min = 0, max = 1, step = 0.05, decimals = 2 },
        { type = "SLIDER", key = "borderSize", label = "Border thickness",
            min = 1, max = 4, step = 1, suffix = " px" },
        { type = "COLOR", key = "headerColor", label = "Header background" },
        { type = "SLIDER", key = "headerOpacity", label = "Header opacity",
            min = 0, max = 1, step = 0.05, decimals = 2 },
        { type = "SLIDER", key = "headerHeight", label = "Header height",
            min = 16, max = 40, step = 1, suffix = " px" },
        { type = "RESET", label = "Reset Window" },
    },
    get = function()
        local style = NSkin:GetStyle("window")
        return {
            backgroundColor = CopyColor(style.background),
            backgroundOpacity = style.background[4] or 1,
            borderSize = style.borderSize,
            headerColor = CopyColor(style.header.background),
            headerOpacity = style.header.background[4] or 1,
            headerHeight = style.header.height,
        }
    end,
    set = function(_, values)
        local style = NSkin:GetStyle("window")
        local changed = SetColor("window.background", style.background,
            values.backgroundColor, values.backgroundOpacity)
        changed = SetScalar("window.borderSize", style.borderSize, values.borderSize) or changed
        changed = SetColor("window.header.background", style.header.background,
            values.headerColor, values.headerOpacity) or changed
        changed = SetScalar("window.header.height", style.header.height,
            values.headerHeight) or changed
        return changed == true
    end,
    reset = function()
        return ResetPaths({ "window.background", "window.borderSize",
            "window.header.background", "window.header.height" })
    end,
})

local function RegisterColorAppearanceGroup(id, styleName, controls)
    NSkin:RegisterOptionGroup(id, {
        controls = controls,
        get = function()
            local style = NSkin:GetStyle(styleName)
            local values = {}
            if style.background then
                values.backgroundColor = CopyColor(style.background)
                values.backgroundOpacity = style.background[4] or 1
            end
            if style.selectedBackground then
                values.selectedColor = CopyColor(style.selectedBackground)
                values.selectedOpacity = style.selectedBackground[4] or 1
            end
            if style.border then
                values.border = CopyColor(NSkin:GetComponentBorderSetting(styleName, style))
            end
            if style.text then values.text = CopyColor(style.text) end
            values.hoverAlpha = style.hoverAlpha
            return values
        end,
        set = function(_, values)
            local style = NSkin:GetStyle(styleName)
            local changed
            if style.background then
                changed = SetColor(styleName .. ".background", style.background,
                    values.backgroundColor, values.backgroundOpacity)
            end
            if style.selectedBackground then
                changed = SetColor(styleName .. ".selectedBackground",
                    style.selectedBackground, values.selectedColor,
                    values.selectedOpacity) or changed
            end
            if style.border and values.border then
                local currentBorder = NSkin:GetComponentBorderSetting(styleName, style)
                if not ColorsEqual(currentBorder, values.border) then
                    changed = NSkin:SetComponentBorderColor(styleName, values.border) or changed
                end
            end
            if style.text and values.text then
                changed = SetColor(styleName .. ".text", style.text,
                    values.text, values.text[4]) or changed
            end
            changed = SetScalar(styleName .. ".hoverAlpha", style.hoverAlpha,
                values.hoverAlpha) or changed
            return changed == true
        end,
        reset = function()
            local paths = { styleName .. ".background" }
            if NSkin.baseAppearance[styleName].selectedBackground then
                paths[#paths + 1] = styleName .. ".selectedBackground"
            end
            if NSkin.baseAppearance[styleName].hoverAlpha ~= nil then
                paths[#paths + 1] = styleName .. ".hoverAlpha"
            end
            if NSkin.baseAppearance[styleName].text then
                paths[#paths + 1] = styleName .. ".text"
            end
            local changed = ResetPaths(paths)
            changed = NSkin:ResetComponentBorderColor(styleName) or changed
            return changed == true
        end,
    })
end

RegisterColorAppearanceGroup("appearance.button", "button", {
    { type = "COLOR", key = "backgroundColor", label = "Button background" },
    { type = "SLIDER", key = "backgroundOpacity", label = "Background opacity",
        min = 0, max = 1, step = 0.05, decimals = 2 },
    { type = "SLIDER", key = "hoverAlpha", label = "Hover opacity",
        min = 0, max = 0.5, step = 0.01, decimals = 2 },
    { type = "COLOR", key = "border", label = "Button border" },
    { type = "COLOR", key = "text", label = "Button text" },
    { type = "RESET", label = "Reset Buttons" },
})

RegisterColorAppearanceGroup("appearance.tab", "tab", {
    { type = "COLOR", key = "backgroundColor", label = "Tab background" },
    { type = "SLIDER", key = "backgroundOpacity", label = "Background opacity",
        min = 0, max = 1, step = 0.05, decimals = 2 },
    { type = "COLOR", key = "selectedColor", label = "Selected background" },
    { type = "SLIDER", key = "selectedOpacity", label = "Selected opacity",
        min = 0, max = 1, step = 0.05, decimals = 2 },
    { type = "SLIDER", key = "hoverAlpha", label = "Hover opacity",
        min = 0, max = 0.5, step = 0.01, decimals = 2 },
    { type = "COLOR", key = "border", label = "Tab border" },
    { type = "RESET", label = "Reset Tabs" },
})

RegisterColorAppearanceGroup("appearance.search", "searchBox", {
    { type = "COLOR", key = "backgroundColor", label = "Search background" },
    { type = "SLIDER", key = "backgroundOpacity", label = "Background opacity",
        min = 0, max = 1, step = 0.05, decimals = 2 },
    { type = "COLOR", key = "border", label = "Search border" },
    { type = "RESET", label = "Reset Search Boxes" },
})

NSkin:RegisterOptionGroup("appearance.progress", {
    controls = {
        { type = "COLOR", key = "backgroundColor", label = "Bar background" },
        { type = "SLIDER", key = "backgroundOpacity", label = "Background opacity",
            min = 0, max = 1, step = 0.05, decimals = 2 },
        { type = "SLIDER", key = "height", label = "Bar height",
            min = 6, max = 40, step = 1, suffix = " px" },
        { type = "CHECKBOX", key = "useCustomColor", label = "Use custom fill color" },
        { type = "COLOR", key = "color", label = "Fill color" },
        { type = "CHECKBOX", key = "useCustomTextColor", label = "Use custom text color" },
        { type = "COLOR", key = "text", label = "Text color" },
        { type = "RESET", label = "Reset Progress Bars" },
    },
    get = function()
        local style = NSkin:GetStyle("progressBar")
        return {
            backgroundColor = CopyColor(style.background),
            backgroundOpacity = style.background[4] or 1,
            height = style.height,
            useCustomColor = style.useCustomColor,
            color = CopyColor(style.color),
            useCustomTextColor = style.useCustomTextColor,
            text = CopyColor(style.text),
        }
    end,
    set = function(_, values)
        local style = NSkin:GetStyle("progressBar")
        local changed = SetColor("progressBar.background", style.background,
            values.backgroundColor, values.backgroundOpacity)
        changed = SetScalar("progressBar.height", style.height, values.height) or changed
        changed = SetScalar("progressBar.useCustomColor", style.useCustomColor,
            values.useCustomColor) or changed
        changed = SetColor("progressBar.color", style.color, values.color,
            values.color[4]) or changed
        changed = SetScalar("progressBar.useCustomTextColor", style.useCustomTextColor,
            values.useCustomTextColor) or changed
        changed = SetColor("progressBar.text", style.text, values.text,
            values.text[4]) or changed
        return changed == true
    end,
    reset = function()
        return ResetPaths({ "progressBar.background", "progressBar.height",
            "progressBar.useCustomColor", "progressBar.color",
            "progressBar.useCustomTextColor", "progressBar.text" })
    end,
})

NSkin:RegisterOptionGroup("appearance.icon", {
    controls = {
        { type = "COLOR", key = "border", label = "Icon border" },
        { type = "SLIDER", key = "crop", label = "Icon crop",
            min = 0, max = 0.2, step = 0.01, decimals = 2 },
        { type = "CHECKBOX", key = "qualityColor", label = "Use item-quality colors" },
        { type = "RESET", label = "Reset Icons" },
    },
    get = function()
        local style = NSkin:GetStyle("icon")
        return { border = CopyColor(style.border), crop = style.crop,
            qualityColor = style.qualityColor }
    end,
    set = function(_, values)
        local style = NSkin:GetStyle("icon")
        local changed = SetColor("icon.border", style.border, values.border, values.border[4])
        changed = SetScalar("icon.crop", style.crop, values.crop) or changed
        changed = SetScalar("icon.qualityColor", style.qualityColor,
            values.qualityColor) or changed
        return changed == true
    end,
    reset = function()
        return ResetPaths({ "icon.border", "icon.crop", "icon.qualityColor" })
    end,
})

local function BuildAppearanceOptions(parent)
    local page = NSkin:CreateOptionsPage(parent)
    local title = page:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT")
    title:SetText("Appearance")

    local views = {}
    local y = 38
    local groups = {
        { "Typography", "appearance.typography" },
        { "Windows", "appearance.window" },
        { "Buttons", "appearance.button" },
        { "Tabs", "appearance.tab" },
        { "Search boxes", "appearance.search" },
        { "Progress bars", "appearance.progress" },
        { "Icons", "appearance.icon" },
    }
    for i = 1, #groups do
        local _, contentY = NSkin:CreateOptionsSection(page, groups[i][1], y)
        local view = NSkin:CreateOptionGroupView(page, groups[i][2], "FULL", page)
        view:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -contentY)
        views[#views + 1] = view
        y = contentY + view:GetHeight() + 24
    end

    function page:ApplyAppearance()
        for i = 1, #views do views[i]:ApplyAppearance() end
    end
    function page:Refresh()
        for i = 1, #views do views[i]:Refresh() end
        self:ApplyAppearance()
    end

    page:SetContentHeight(y)
    return page
end

NSkin:RegisterOptionsPage({
    key = "appearance",
    label = "Appearance",
    group = "shared",
    order = 1,
    builder = BuildAppearanceOptions,
})

end

do
local _, NSkin = ...

local function CopyColor(color)
    return { color[1], color[2], color[3], color[4] or 1 }
end

local function BuildBorderOptions(parent)
    local page = NSkin:CreateOptionsPage(parent)

    local title = page:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT")
    title:SetText("Border")

    local description = page:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    description:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -28)
    description:SetPoint("TOPRIGHT", page, "TOPRIGHT", 0, -28)
    description:SetJustifyH("LEFT")
    description:SetText(
        "Choose the border inherited by NSkin components without their own override. "
        .. "Optionally enable an "
        .. "accent color for windows, tabs, search boxes, buttons, and "
        .. "progress-bar fills and borders. "
        .. "Icon and item-quality borders keep their own colors."
    )

    NSkin:CreateOptionsSection(page, "Shared border", 82)
    local colorLabel = page:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    colorLabel:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -114)
    colorLabel:SetText("Color")

    local swatch = CreateFrame("Button", nil, page)
    swatch:SetSize(64, 24)
    swatch:SetPoint("LEFT", colorLabel, "RIGHT", 12, 0)

    local reset = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
    reset:SetSize(110, 24)
    reset:SetPoint("TOPLEFT", colorLabel, "BOTTOMLEFT", 0, -18)
    if reset:GetFontString() then reset:GetFontString():SetAlpha(0) end

    NSkin:CreateOptionsSection(page, "Accent", 170)
    local accentToggle = NSkin:CreateOwnedOptionsCheckbox(page)
    accentToggle:SetPoint("TOPLEFT", page, "TOPLEFT", -4, -202)
    if accentToggle.Text then
        accentToggle.Text:SetText("Use accent for shared controls and progress bars")
    end

    local accentLabel = page:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    accentLabel:SetPoint("TOPLEFT", accentToggle, "BOTTOMLEFT", 4, -16)
    accentLabel:SetText("Accent color")

    local accentSwatch = CreateFrame("Button", nil, page)
    accentSwatch:SetSize(64, 24)
    accentSwatch:SetPoint("LEFT", accentLabel, "RIGHT", 12, 0)

    local resetAccent = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
    resetAccent:SetSize(110, 24)
    resetAccent:SetPoint("TOPLEFT", accentLabel, "BOTTOMLEFT", 0, -20)
    if resetAccent:GetFontString() then resetAccent:GetFontString():SetAlpha(0) end

    local function ApplyPickerColor()
        local red, green, blue = ColorPickerFrame:GetColorRGB()
        NSkin:SetBorderAccentColor({ red, green, blue, 1 })
        page:Refresh()
    end

    swatch:SetScript("OnClick", function()
        local previousColor = CopyColor(NSkin:GetBorderAccentColor())
        local info = {
            r = previousColor[1],
            g = previousColor[2],
            b = previousColor[3],
            swatchFunc = ApplyPickerColor,
            cancelFunc = function()
                NSkin:SetBorderAccentColor(previousColor)
                page:Refresh()
            end,
        }
        ColorPickerFrame:SetupColorPickerAndShow(info)
    end)

    local function ApplyAccentPickerColor()
        local red, green, blue = ColorPickerFrame:GetColorRGB()
        NSkin:SetAccentColor({ red, green, blue, 1 })
        page:Refresh()
    end

    accentSwatch:SetScript("OnClick", function()
        local previousColor = CopyColor(NSkin:GetAccentColor())
        local info = {
            r = previousColor[1],
            g = previousColor[2],
            b = previousColor[3],
            swatchFunc = ApplyAccentPickerColor,
            cancelFunc = function()
                NSkin:SetAccentColor(previousColor)
                page:Refresh()
            end,
        }
        ColorPickerFrame:SetupColorPickerAndShow(info)
    end)

    accentToggle:SetScript("OnClick", function(self)
        NSkin:SetAccentColorEnabled(self:GetChecked() == true)
        page:Refresh()
    end)

    reset:SetScript("OnClick", function()
        NSkin:ResetBorderAccentColor()
        page:Refresh()
    end)

    resetAccent:SetScript("OnClick", function()
        NSkin:ResetAccentColor()
        page:Refresh()
    end)

    function page:ApplyAppearance()
        local color = NSkin:GetBorderAccentColor()
        local buttonStyle = NSkin:GetStyle("button")
        NSkin:CreateFlatBackground(swatch, "NSkinBorderColorSwatch",
            color, buttonStyle.border)
        NSkin:CreateFlatBackground(accentSwatch, "NSkinAccentColorSwatch",
            NSkin:GetAccentColor(), buttonStyle.border)
        NSkin:SkinFlatButton(reset, "Reset Default", nil, nil, 12)
        NSkin:SkinFlatButton(resetAccent, "Reset Accent", nil, nil, 12)
        accentToggle:SetChecked(NSkin:IsAccentColorEnabled())
    end

    function page:Refresh()
        self:ApplyAppearance()
    end

    page:SetContentHeight(330)
    return page
end

NSkin:RegisterOptionsPage({
    key = "border",
    label = "Border",
    group = "shared",
    order = 5,
    builder = BuildBorderOptions,
})

end

do
local _, NSkin = ...

local function CreateTabControls(includeSpacing)
    local controls = {
        { type = "SLIDER_PAIR", order = 1, centerReset = true,
            resetGroup = true,
            resetTooltip = "Reset X and Y offsets",
            left = { key = "alongOffset", label = "X offset", min = -200,
                max = 200, step = 0.1, decimals = 1, suffix = " px" },
            right = { key = "edgeOffset", label = "Y offset", min = -200,
                max = 200, step = 0.1, decimals = 1, suffix = " px" } },
    }
    if includeSpacing then
        controls[#controls + 1] = {
            type = "SLIDER",
            key = "spacing",
            label = "Spacing",
            min = -30,
            max = 30,
            step = 1,
            suffix = " px",
            order = 6,
        }
    end
    if includeSpacing then
        controls[#controls + 1] = {
            type = "RESET", label = "Reset Default", compactLabel = "Reset",
        }
    end
    return controls
end

local function GetValues(context, includeSpacing)
    local values = NSkin:GetTabGroupPlacement(context.id)
    NSkin:NormalizeGridPlacementForEditor(context, values)
    if includeSpacing then values.spacing = NSkin:GetTabSpacing() end
    return values
end

local function SetValues(context, values, includeSpacing)
    local currentPlacement = NSkin:GetTabGroupPlacement(context.id)
    if values.mode == "GRID" then
        values.x = tonumber(values.alongOffset) or values.x or 0
        values.y = tonumber(values.edgeOffset) or values.y or 0
    end
    local placementChanged = values.alignment ~= nil
        and (values.mode ~= currentPlacement.mode
            or values.x ~= currentPlacement.x
            or values.y ~= currentPlacement.y
            or values.relativeTo ~= currentPlacement.relativeTo
            or values.point ~= currentPlacement.point
            or values.relativePoint ~= currentPlacement.relativePoint
            or values.edge ~= currentPlacement.edge
            or values.side ~= currentPlacement.side
            or values.alignment ~= currentPlacement.alignment
            or values.alongOffset ~= currentPlacement.alongOffset
            or values.edgeOffset ~= currentPlacement.edgeOffset)
    local spacingChanged = includeSpacing and values.spacing ~= nil
        and values.spacing ~= NSkin:GetTabSpacing()
    local changed
    if placementChanged then
        changed = NSkin:SetTabGroupPlacement(context.id, values) or changed
    end
    if spacingChanged then
        changed = NSkin:SetTabSpacing(values.spacing) or changed
    end
    return changed == true
end

NSkin:RegisterOptionGroup("tabs.layout", {
    controls = CreateTabControls(false),
    get = function(context)
        return GetValues(context, false)
    end,
    set = function(context, values)
        return SetValues(context, values, false)
    end,
    reset = function(context)
        return NSkin:ResetTabGroupPlacement(context.id)
    end,
})

NSkin:RegisterOptionGroup("tabs.defaults", {
    controls = CreateTabControls(true),
    get = function(context)
        return GetValues(context, true)
    end,
    set = function(context, values)
        return SetValues(context, values, true)
    end,
    reset = function(context)
        local changed = NSkin:ResetTabGroupPlacement(context.id)
        changed = NSkin:ResetTabSpacing() or changed
        return changed == true
    end,
})

local function BuildTabsOptions(parent)
    local page = NSkin:CreateOptionsPage(parent)

    local title = page:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT")
    title:SetText("Tabs")

    NSkin:CreateOptionsSection(page, "Shared defaults", 38)
    local layoutView = NSkin:CreateOptionGroupView(page, "tabs.defaults", "FULL", page)
    layoutView:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -70)

    function page:ApplyAppearance()
        if layoutView.ApplyAppearance then layoutView:ApplyAppearance() end
    end

    function page:Refresh()
        layoutView:Refresh()
        self:ApplyAppearance()
    end

    page:SetContentHeight(90 + layoutView:GetHeight())
    return page
end

-- Placement belongs to the docked Position category. Keep the option-group
-- definitions for the inspector, but do not expose placement globally.

end

do
local _, NSkin = ...

local function CopyColor(color)
    return { color[1], color[2], color[3], color[4] or 1 }
end

function NSkin:NormalizeGridPlacementForEditor(context, values)
    if not values or values.mode ~= "GRID" then return values end
    local window, target = context and context.window, context and context.target
    if not window or not target then return values end
    local windowWidth, windowHeight = window:GetWidth(), window:GetHeight()
    local targetWidth, targetHeight = target:GetWidth(), target:GetHeight()
    local x, y = tonumber(values.x) or 0, tonumber(values.y) or 0
    local centerX, centerY = x + targetWidth / 2, y - targetHeight / 2
    local alignment = centerX < windowWidth / 3 and "LEFT"
        or (centerX < windowWidth * 2 / 3 and "CENTER" or "RIGHT")
    local edge = centerY > -windowHeight / 2 and "TOP" or "BOTTOM"
    local side = centerY <= 0 and centerY >= -windowHeight and "INSIDE" or "OUTSIDE"
    values.alignment, values.edge, values.side = alignment, edge, side
    values.alongOffset = alignment == "LEFT" and x
        or (alignment == "CENTER" and x + targetWidth / 2 - windowWidth / 2
            or x + targetWidth - windowWidth)
    values.edgeOffset = edge == "TOP"
        and (side == "INSIDE" and y or y - targetHeight)
        or (side == "INSIDE" and y - targetHeight + windowHeight or y + windowHeight)
    values.mode, values.point, values.relativePoint = nil, nil, nil
    values.x, values.y, values.relativeTo = nil, nil, nil
    return values
end

function NSkin:CreateSharedPlacementControls(extra)
    local controls = {
        { type = "SLIDER_PAIR", order = 1, centerReset = true,
            resetGroup = true,
            resetTooltip = "Reset X and Y offsets",
            left = { key = "alongOffset", label = "X offset", min = -200,
                max = 200, step = 0.1, decimals = 1, suffix = " px" },
            right = { key = "edgeOffset", label = "Y offset", min = -200,
                max = 200, step = 0.1, decimals = 1, suffix = " px" } },
    }
    for i = 1, #(extra or {}) do controls[#controls + 1] = extra[i] end
    return controls
end

function NSkin:NormalizeSharedPlacementValues(context, values)
    if values.mode == "GRID" then
        values.x, values.y = values.alongOffset, values.edgeOffset
    end
    return values
end

NSkin:RegisterOptionGroup("shared.movable", {
    controls = NSkin:CreateSharedPlacementControls(),
    get = function(context)
        local values = context.getPlacement(context)
        return NSkin:NormalizeGridPlacementForEditor(context, values)
    end,
    set = function(context, values)
        return context.setPlacement(context, NSkin:NormalizeSharedPlacementValues(context, values))
    end,
    reset = function(context)
        return context.resetPlacement(context)
    end,
})

NSkin:RegisterOptionGroup("shared.paginationPosition", {
    controls = NSkin:CreateSharedPlacementControls(),
    get = function(context)
        local values = context.getPlacement(context)
        return NSkin:NormalizeGridPlacementForEditor(context, values)
    end,
    set = function(context, values)
        return context.setPlacement(context,
            NSkin:NormalizeSharedPlacementValues(context, values))
    end,
    reset = function(context) return context.resetPlacement(context) end,
})

NSkin:RegisterOptionGroup("shared.paginationLayout", {
    controls = {
        { type = "CONTROL_PAIR",
            left = { type = "CHECKBOX", key = "separateButtons",
                label = "Move buttons independently" },
            right = { type = "DROPDOWN", key = "textMode", label = "Page text",
                values = { { value = "GROUPED", label = "Grouped",
                        isEnabled = function(context)
                            return context and not context.getPaginationSeparateButtons(context)
                        end },
                    { value = "INDEPENDENT", label = "Independent" },
                    { value = "HIDDEN", label = "Hidden" } } } },
        { type = "RESET", label = "Reset Layout", compactLabel = "Reset" },
    },
    get = function(context)
        return { separateButtons = context.getPaginationSeparateButtons(context),
            textMode = context.getPaginationTextMode(context) }
    end,
    set = function(context, values)
        local changed
        local separate = context.getPaginationSeparateButtons(context)
        if values.separateButtons ~= nil and values.separateButtons ~= separate then
            changed = context.setPaginationSeparateButtons(context,
                values.separateButtons) or changed
            separate = values.separateButtons == true
        end
        local textMode = values.textMode
        if separate and textMode == "GROUPED" then textMode = "INDEPENDENT" end
        if textMode == "GROUPED" or textMode == "INDEPENDENT" or textMode == "HIDDEN" then
            changed = context.setPaginationTextMode(context, textMode) or changed
        end
        return changed == true
    end,
    reset = function(context)
        local changed = context.setPaginationSeparateButtons(context, false)
        changed = context.setPaginationTextMode(context, "GROUPED") or changed
        return changed == true
    end,
})

NSkin:RegisterOptionGroup("shared.searchPosition", {
    controls = NSkin:CreateSharedPlacementControls(),
    get = function(context)
        local values = context.getPlacement(context)
        return NSkin:NormalizeGridPlacementForEditor(context, values)
    end,
    set = function(context, values)
        return context.setPlacement(context,
            NSkin:NormalizeSharedPlacementValues(context, values))
    end,
    reset = function(context) return context.resetPlacement(context) end,
})

local GLOBAL_VALUE = "__NSKIN_GLOBAL__"
local function FONT_VALUES()
    return NSkin:GetAvailableFontOptions(true)
end
local OUTLINE_VALUES = {
    { value = GLOBAL_VALUE, label = "NSkin Global Outline" },
    { divider = true },
    { value = "", label = "None" },
    { value = "OUTLINE", label = "Outline" },
    { value = "THICKOUTLINE", label = "Thick outline" },
    { value = "MONOCHROME,OUTLINE", label = "Monochrome outline" },
}
local function AddTypographyControls(controls, keys, label, order, color)
    controls[#controls + 1] = {
        type = "TYPOGRAPHY", label = label, order = order,
        sizeKey = keys.size, sizeLabel = "Size", sizeMin = 8, sizeMax = 32,
        fontKey = keys.font, fontLabel = "Font", fontValues = FONT_VALUES,
        outlineKey = keys.outline, outlineLabel = "Outline",
        outlineValues = OUTLINE_VALUES,
        color = color,
    }
end

local function GetTypographyValues(values, style, keys, prefix)
    prefix = prefix or ""
    local fontMode = style[prefix == "" and "fontMode" or prefix .. "FontMode"]
    local sizeMode = style[prefix == "" and "sizeMode" or prefix .. "SizeMode"]
    local outlineMode = style[prefix == "" and "outlineMode" or prefix .. "OutlineMode"]
    values[keys.font] = fontMode == "GLOBAL" and GLOBAL_VALUE
        or style[prefix == "" and "font" or prefix .. "Font"]
    values[keys.size] = sizeMode == "GLOBAL" and GLOBAL_VALUE
        or style[prefix == "" and "textSize" or prefix .. "Size"]
    values[keys.outline] = outlineMode == "GLOBAL" and GLOBAL_VALUE
        or style[prefix == "" and "outline" or prefix .. "Outline"]
end

local SetElementValue

local function GetAppearanceWindowID(context)
    return context.appearanceWindowID
end

local function SetElementTypography(context, stylePath, values, keys, prefix)
    prefix = prefix or ""
    local fontKey = prefix == "" and "font" or prefix .. "Font"
    local sizeKey = prefix == "" and "textSize" or prefix .. "Size"
    local outlineKey = prefix == "" and "outline" or prefix .. "Outline"
    local fontModeKey = prefix == "" and "fontMode" or prefix .. "FontMode"
    local sizeModeKey = prefix == "" and "sizeMode" or prefix .. "SizeMode"
    local outlineModeKey = prefix == "" and "outlineMode" or prefix .. "OutlineMode"
    local changed
    if values[keys.font] ~= nil then
        changed = SetElementValue(context, stylePath .. "." .. fontModeKey,
            values[keys.font] == GLOBAL_VALUE and "GLOBAL" or "CUSTOM") or changed
    end
    if values[keys.size] ~= nil then
        changed = SetElementValue(context, stylePath .. "." .. sizeModeKey,
            values[keys.size] == GLOBAL_VALUE and "GLOBAL" or "CUSTOM") or changed
    end
    if values[keys.outline] ~= nil then
        changed = SetElementValue(context, stylePath .. "." .. outlineModeKey,
            values[keys.outline] == GLOBAL_VALUE and "GLOBAL" or "CUSTOM") or changed
    end
    if values[keys.font] ~= nil and values[keys.font] ~= GLOBAL_VALUE then
        changed = SetElementValue(context, stylePath .. "." .. fontKey,
            values[keys.font]) or changed
    end
    if values[keys.size] ~= nil and values[keys.size] ~= GLOBAL_VALUE then
        changed = SetElementValue(context, stylePath .. "." .. sizeKey,
            values[keys.size]) or changed
    end
    if values[keys.outline] ~= nil and values[keys.outline] ~= GLOBAL_VALUE then
        changed = SetElementValue(context, stylePath .. "." .. outlineKey,
            values[keys.outline]) or changed
    end
    return changed == true
end

SetElementValue = function(context, path, value)
    return NSkin:SetElementAppearanceOverride(
        context.id, GetAppearanceWindowID(context), path, value)
end

local function ResetElementPaths(context, paths)
    return NSkin:ResetElementAppearanceOverrides(context.id, paths)
end

local function CreateBorderGeometryControls(order)
    return { type = "SLIDER_PAIR", order = order, centerReset = true,
        resetTooltip = "Reset border size and padding",
        left = { key = "borderSize", label = "Border size", min = 1,
            max = 4, step = 1, decimals = 0, suffix = " px", resetValue = 1 },
        right = { key = "borderPadding", label = "Border padding", min = -10,
            max = 20, step = 1, decimals = 0, suffix = " px", resetValue = 0 } }
end

local function ResetMappedElementKeys(context, keys, pathsByKey)
    local paths, seen = {}, {}
    for key in pairs(keys) do
        local mapped = pathsByKey[key]
        if type(mapped) == "string" then mapped = { mapped } end
        if type(mapped) == "table" then
            for i = 1, #mapped do
                if not seen[mapped[i]] then
                    seen[mapped[i]] = true
                    paths[#paths + 1] = mapped[i]
                end
            end
        end
    end
    return #paths > 0 and ResetElementPaths(context, paths) or false
end

NSkin:RegisterOptionGroup("shared.scrollBarAppearance", {
    controls = {
        {
            type = "COLOR_PAIR", order = 1,
            left = { type = "COLOR", key = "track", modeKey = "trackMode",
                label = "Bar" },
            right = { type = "COLOR", key = "thumb", modeKey = "thumbMode",
                label = "Thumb" },
        },
        {
            type = "COLOR", key = "arrow", modeKey = "arrowMode",
            label = "Arrows", order = 2,
        },
    },
    get = function(context)
        local style = NSkin:GetAppearanceStyle(
            "scrollBar", GetAppearanceWindowID(context), context.id)
        return {
            track = CopyColor(style.track), trackMode = style.trackMode,
            thumb = CopyColor(style.thumb), thumbMode = style.thumbMode,
            arrow = CopyColor(style.arrow), arrowMode = style.arrowMode,
        }
    end,
    set = function(context, values)
        local changed
        for _, key in ipairs({ "track", "trackMode", "thumb", "thumbMode",
            "arrow", "arrowMode" })
        do
            if values[key] ~= nil then
                changed = SetElementValue(
                    context, "scrollBar." .. key, values[key]) or changed
            end
        end
        return changed == true
    end,
    reset = function(context)
        return ResetElementPaths(context, {
            "scrollBar.track", "scrollBar.trackMode",
            "scrollBar.thumb", "scrollBar.thumbMode",
            "scrollBar.arrow", "scrollBar.arrowMode",
        })
    end,
})

local sideTabResetPaths = {
    width = "sideTab.width",
    height = "sideTab.height",
    border = "sideTab.border",
    borderMode = "sideTab.borderMode",
    background = "sideTab.background",
    backgroundMode = "sideTab.backgroundMode",
    hoverAlpha = "sideTab.hoverAlpha",
}

NSkin:RegisterOptionGroup("shared.sideTabAppearance", {
    controls = {
        {
            type = "SLIDER_PAIR", order = 1, centerReset = true,
            resetSubset = true,
            resetTooltip = "Reset side-tab width and height",
            left = { key = "width", label = "Width", min = 20,
                max = 100, step = 1, decimals = 0, suffix = " px",
                resetValue = 0 },
            right = { key = "height", label = "Height", min = 20,
                max = 100, step = 1, decimals = 0, suffix = " px",
                resetValue = 0 },
        },
        {
            type = "COLOR_PAIR", order = 2,
            left = { type = "COLOR", key = "border",
                modeKey = "borderMode", label = "Border" },
            right = { type = "COLOR", key = "background",
                modeKey = "backgroundMode", label = "Background" },
        },
        {
            type = "SLIDER", key = "hoverAlpha",
            label = "Highlight opacity", min = 0, max = 1,
            step = 0.05, decimals = 2, order = 3,
        },
    },
    get = function(context)
        local style = NSkin:GetAppearanceStyle(
            "sideTab", GetAppearanceWindowID(context), context.id)
        local target = context.target
        return {
            width = tonumber(style.width) and style.width > 0 and style.width
                or (target and target.GetWidth and target:GetWidth()) or 43,
            height = tonumber(style.height) and style.height > 0 and style.height
                or (target and target.GetHeight and target:GetHeight()) or 55,
            border = CopyColor(style.border),
            borderMode = style.borderMode,
            background = CopyColor(style.background),
            backgroundMode = style.backgroundMode,
            hoverAlpha = tonumber(style.hoverAlpha) or 0.10,
        }
    end,
    set = function(context, values)
        local changed
        for _, key in ipairs({ "width", "height", "border", "borderMode",
            "background", "backgroundMode", "hoverAlpha" })
        do
            if values[key] ~= nil then
                changed = SetElementValue(
                    context, "sideTab." .. key, values[key]) or changed
            end
        end
        return changed == true
    end,
    reset = function(context)
        return ResetElementPaths(context, {
            "sideTab.width", "sideTab.height", "sideTab.border",
            "sideTab.borderMode", "sideTab.background",
            "sideTab.backgroundMode", "sideTab.hoverAlpha",
        })
    end,
    resetSubset = function(context, keys)
        return ResetMappedElementKeys(context, keys, sideTabResetPaths)
    end,
})

local windowHeaderControlsAppearance = {
    {
        type = "SLIDER_PAIR", order = 1, centerReset = true,
        resetSubset = true,
        resetTooltip = "Reset button width and height",
        left = { key = "width", label = "Button size", min = 16,
            max = 64, step = 1, decimals = 0, suffix = " px" },
        right = { key = "height", label = "Height", min = 16,
            max = 64, step = 1, decimals = 0, suffix = " px" },
    },
    {
        type = "SLIDER", key = "textSize", label = "Text size",
        min = 8, max = 32, step = 1, decimals = 0, suffix = " px",
        order = 2,
    },
    {
        type = "COLOR_PAIR", order = 3,
        left = { type = "COLOR", key = "border", modeKey = "borderMode",
            label = "Border" },
        right = { type = "COLOR", key = "background",
            modeKey = "backgroundMode", label = "Background" },
    },
    {
        type = "SLIDER", key = "hoverAlpha", label = "Highlight intensity",
        min = 0, max = 1, step = 0.05, decimals = 2, order = 4,
    },
}

local windowHeaderControlResetPaths = {
    width = "windowHeaderButton.width",
    height = "windowHeaderButton.height",
    textSize = "windowHeaderButton.textSize",
    border = "windowHeaderButton.border",
    borderMode = "windowHeaderButton.borderMode",
    background = "windowHeaderButton.background",
    backgroundMode = "windowHeaderButton.backgroundMode",
    hoverAlpha = "windowHeaderButton.hoverAlpha",
}

NSkin:RegisterOptionGroup("shared.windowHeaderControlsAppearance", {
    controls = windowHeaderControlsAppearance,
    get = function(context)
        local style = NSkin:GetAppearanceStyle(
            "windowHeaderButton", GetAppearanceWindowID(context), context.id)
        local regions = NSkin:GetWindowHeaderControlRegions(
            context.window, context.id)
        local closeButton = regions[1] or context.target
        return {
            width = tonumber(style.width) and style.width > 0 and style.width
                or (closeButton
                and closeButton.GetWidth and closeButton:GetWidth()) or 24,
            height = tonumber(style.height) and style.height > 0 and style.height
                or (closeButton
                and closeButton.GetHeight and closeButton:GetHeight()) or 24,
            textSize = tonumber(style.textSize) or 20,
            border = CopyColor(style.border),
            borderMode = style.borderMode,
            background = CopyColor(style.background),
            backgroundMode = style.backgroundMode,
            hoverAlpha = tonumber(style.hoverAlpha) or 0.10,
        }
    end,
    set = function(context, values)
        local changed
        for _, key in ipairs({ "width", "height", "textSize", "border",
            "borderMode", "background", "backgroundMode", "hoverAlpha" })
        do
            if values[key] ~= nil then
                changed = SetElementValue(context,
                    "windowHeaderButton." .. key, values[key]) or changed
            end
        end
        return changed == true
    end,
    reset = function(context)
        return ResetElementPaths(context, {
            "windowHeaderButton.width", "windowHeaderButton.height",
            "windowHeaderButton.textSize", "windowHeaderButton.border",
            "windowHeaderButton.borderMode",
            "windowHeaderButton.background",
            "windowHeaderButton.backgroundMode",
            "windowHeaderButton.hoverAlpha",
        })
    end,
    resetSubset = function(context, keys)
        return ResetMappedElementKeys(
            context, keys, windowHeaderControlResetPaths)
    end,
})

local tabBorderGeometryControls = CreateBorderGeometryControls(13)
local tabSizeControls = {
    type = "SLIDER_PAIR", order = 2, centerReset = true,
    resetTooltip = "Reset tab width and height",
    left = { key = "width", label = "Width", min = 40, max = 300,
        step = 1, decimals = 0, suffix = " px", resetValue = 0 },
    right = { key = "height", label = "Height", min = 16, max = 80,
        step = 1, decimals = 0, suffix = " px", resetValue = 0 },
}
local tabSpacingControl = { type = "SLIDER", key = "spacing", label = "Spacing",
    min = -30, max = 30, step = 1, decimals = 0, suffix = " px", order = 3 }
local tabAppearanceControls = {
    tabSizeControls, tabSpacingControl, tabBorderGeometryControls,
}
local function GetFirstTabSize(context)
    local group = context and NSkin:GetTabGroup(context.id)
    local tabs = group and ((group.container and group.container.tabs) or group.tabs)
    local tab = type(tabs) == "table" and tabs[1]
    return tab and tab.GetWidth and tab:GetWidth() or 40,
        tab and tab.GetHeight and tab:GetHeight() or 16
end
AddTypographyControls(tabAppearanceControls,
    { useGlobal = "useGlobal", font = "font", size = "textSize", outline = "outline" },
    "Tab Text", 1, { type = "COLOR", key = "text", modeKey = "textMode",
        label = "Color" })
tabAppearanceControls[#tabAppearanceControls + 1] = {
    type = "SECTION", label = "Tabs", order = 10,
}
tabAppearanceControls[#tabAppearanceControls + 1] = {
    type = "COLOR_PAIR", order = 11,
    left = { type = "COLOR", key = "border", modeKey = "borderMode",
        label = "Border" },
    right = { type = "COLOR", key = "background", modeKey = "backgroundMode",
        label = "Background" },
}
tabAppearanceControls[#tabAppearanceControls + 1] = {
    type = "COLOR", key = "selectedBackground", modeKey = "selectedBackgroundMode",
    label = "Selected background", order = 12,
}
local tabResetPaths = {
    font = { "tab.fontMode", "tab.font" },
    textSize = { "tab.sizeMode", "tab.textSize" },
    outline = { "tab.outlineMode", "tab.outline" },
}
for _, key in ipairs({ "text", "textMode", "background", "backgroundMode",
    "selectedBackground", "selectedBackgroundMode", "border", "borderMode",
    "borderSize", "borderPadding", "width", "height", "spacing" }) do
    tabResetPaths[key] = "tab." .. key
end
NSkin:RegisterOptionGroup("shared.tabAppearance", {
    controls = tabAppearanceControls,
    get = function(context)
        local style = NSkin:GetAppearanceStyle(
            "tab", GetAppearanceWindowID(context), context.id)
        local currentWidth, currentHeight = GetFirstTabSize(context)
        local tabGroup = NSkin:GetTabGroup(context.id)
        local spacing = tonumber(style.spacing)
        if spacing == nil and tabGroup then
            spacing = tonumber(tabGroup.originalSpacing)
        end
        local values = { background = CopyColor(style.background),
            selectedBackground = CopyColor(style.selectedBackground),
            border = CopyColor(style.border), text = CopyColor(style.text),
            textMode = style.textMode, borderSize = style.borderSize,
            borderPadding = style.borderPadding,
            width = tonumber(style.width) and style.width > 0
                and style.width or currentWidth,
            height = tonumber(style.height) and style.height > 0
                and style.height or currentHeight,
            spacing = spacing or 0,
            backgroundMode = style.backgroundMode,
            selectedBackgroundMode = style.selectedBackgroundMode,
            borderMode = style.borderMode }
        GetTypographyValues(values, style,
            { useGlobal = "useGlobal", font = "font", size = "textSize", outline = "outline" })
        return values
    end,
    set = function(context, values)
        local changed = SetElementTypography(context, "tab", values,
            { font = "font", size = "textSize", outline = "outline" })
        for _, key in ipairs({ "text", "textMode", "background", "backgroundMode", "selectedBackground",
            "selectedBackgroundMode", "border", "borderMode", "borderSize",
            "borderPadding", "width", "height", "spacing" }) do
            if values[key] ~= nil then
                changed = SetElementValue(context, "tab." .. key, values[key]) or changed
            end
        end
        return changed == true
    end,
    reset = function(context)
        return ResetElementPaths(context, { "tab.fontMode", "tab.sizeMode",
            "tab.outlineMode", "tab.font", "tab.textSize", "tab.outline",
            "tab.text", "tab.textMode", "tab.background", "tab.backgroundMode", "tab.selectedBackground",
            "tab.selectedBackgroundMode", "tab.border", "tab.borderMode",
            "tab.borderSize", "tab.borderPadding", "tab.width", "tab.height",
            "tab.spacing" })
    end,
    resetSubset = function(context, keys)
        return ResetMappedElementKeys(context, keys, tabResetPaths)
    end,
})

local searchAppearanceControls = {}
AddTypographyControls(searchAppearanceControls,
    { useGlobal = "useGlobal", font = "font", size = "textSize", outline = "outline" },
    "Search Text", 2, { type = "COLOR", key = "text", modeKey = "textMode",
        label = "Color" })
searchAppearanceControls[#searchAppearanceControls + 1] = {
    type = "SLIDER_PAIR", order = 1, centerReset = true,
    resetTooltip = "Reset search text offsets",
    left = { key = "textOffsetX", label = "X offset", min = -50,
        max = 50, step = 0.1, decimals = 1, suffix = " px" },
    right = { key = "textOffsetY", label = "Y offset", min = -50,
        max = 50, step = 0.1, decimals = 1, suffix = " px" },
}
AddTypographyControls(searchAppearanceControls,
    { useGlobal = "placeholderUseGlobal", font = "placeholderFont",
        size = "placeholderSize", outline = "placeholderOutline" },
    "Placeholder Text", 11,
    { type = "COLOR", key = "placeholderText", modeKey = "placeholderTextMode",
        label = "Color" })
searchAppearanceControls[#searchAppearanceControls + 1] = {
    type = "SLIDER_PAIR", order = 10, centerReset = true,
    resetTooltip = "Reset placeholder text offsets",
    left = { key = "placeholderOffsetX", label = "X offset", min = -50,
        max = 50, step = 0.1, decimals = 1, suffix = " px" },
    right = { key = "placeholderOffsetY", label = "Y offset", min = -50,
        max = 50, step = 0.1, decimals = 1, suffix = " px" },
}
searchAppearanceControls[#searchAppearanceControls + 1] = {
    type = "SECTION", label = "Search Box", order = 20,
}
searchAppearanceControls[#searchAppearanceControls + 1] = {
    type = "COLOR_PAIR", order = 21,
    left = { type = "COLOR", key = "border", modeKey = "borderMode",
        label = "Border" },
    right = { type = "COLOR", key = "background", modeKey = "backgroundMode",
        label = "Background" },
}
local searchBorderGeometryControls = CreateBorderGeometryControls(21)
searchAppearanceControls[#searchAppearanceControls + 1] = searchBorderGeometryControls
local searchSizeControls = {
    type = "SLIDER_PAIR", order = 20, centerReset = true,
    resetTooltip = "Reset search box width and height",
    left = { key = "width", label = "Width", min = 80,
        max = 600, step = 1, decimals = 0, suffix = " px" },
    right = { key = "height", label = "Height", min = 16,
        max = 80, step = 1, decimals = 0, suffix = " px" },
}
searchAppearanceControls[#searchAppearanceControls + 1] = searchSizeControls
local searchAccessoryControls = {
    type = "DROPDOWN_PAIR", order = 22,
    right = { key = "accessoryMode", label = "Search accessory",
        labelWidth = 100,
        values = { { value = "GROUPED", label = "Grouped" },
            { value = "INDEPENDENT", label = "Independent" },
            { value = "HIDDEN", label = "Hidden" } } },
}
local searchResetPaths = {
    font = { "searchBox.fontMode", "searchBox.font" },
    textSize = { "searchBox.sizeMode", "searchBox.textSize" },
    outline = { "searchBox.outlineMode", "searchBox.outline" },
    placeholderFont = { "searchBox.placeholderFontMode",
        "searchBox.placeholderFont" },
    placeholderSize = { "searchBox.placeholderSizeMode",
        "searchBox.placeholderSize" },
    placeholderOutline = { "searchBox.placeholderOutlineMode",
        "searchBox.placeholderOutline" },
}
for _, key in ipairs({ "text", "textMode", "textOffsetX", "textOffsetY",
    "placeholderText", "placeholderTextMode", "placeholderOffsetX",
    "placeholderOffsetY", "background", "backgroundMode", "border",
    "borderMode", "borderSize", "borderPadding", "width", "height" }) do
    searchResetPaths[key] = "searchBox." .. key
end
NSkin:RegisterOptionGroup("shared.searchAppearance", {
    controls = searchAppearanceControls,
    get = function(context)
        local style = NSkin:GetAppearanceStyle(
            "searchBox", GetAppearanceWindowID(context), context.id)
        local values = { background = CopyColor(style.background), border = CopyColor(style.border),
            text = CopyColor(style.text), textMode = style.textMode,
            placeholderText = CopyColor(style.placeholderText),
            placeholderTextMode = style.placeholderTextMode,
            borderSize = style.borderSize, borderPadding = style.borderPadding,
            width = tonumber(style.width) and style.width > 0 and style.width
                or (context.target and context.target.GetWidth
                    and context.target:GetWidth()),
            height = tonumber(style.height) and style.height > 0 and style.height
                or (context.target and context.target.GetHeight
                    and context.target:GetHeight()),
            textOffsetX = style.textOffsetX,
            textOffsetY = style.textOffsetY, placeholderOffsetX = style.placeholderOffsetX,
            placeholderOffsetY = style.placeholderOffsetY,
            backgroundMode = style.backgroundMode, borderMode = style.borderMode,
            accessoryMode = context.getSearchAccessoryMode
                and context.getSearchAccessoryMode(context) }
        GetTypographyValues(values, style,
            { useGlobal = "useGlobal", font = "font", size = "textSize", outline = "outline" })
        GetTypographyValues(values, style,
            { useGlobal = "placeholderUseGlobal", font = "placeholderFont",
                size = "placeholderSize", outline = "placeholderOutline" }, "placeholder")
        return values
    end,
    set = function(context, values)
        local changed = SetElementTypography(context, "searchBox", values,
            { font = "font", size = "textSize", outline = "outline" })
        changed = SetElementTypography(context, "searchBox", values,
            { font = "placeholderFont", size = "placeholderSize",
                outline = "placeholderOutline" }, "placeholder") or changed
        local mapping = {
            background = "background", backgroundMode = "backgroundMode",
            border = "border", borderMode = "borderMode", borderSize = "borderSize",
            borderPadding = "borderPadding",
            width = "width", height = "height",
            text = "text", textMode = "textMode",
            textOffsetX = "textOffsetX", textOffsetY = "textOffsetY",
            placeholderText = "placeholderText",
            placeholderTextMode = "placeholderTextMode",
            placeholderOffsetX = "placeholderOffsetX", placeholderOffsetY = "placeholderOffsetY",
        }
        for key, path in pairs(mapping) do
            if values[key] ~= nil then
                changed = SetElementValue(context, "searchBox." .. path, values[key]) or changed
            end
        end
        if values.accessoryMode ~= nil and context.setSearchAccessoryMode
            and context.getSearchAccessoryMode
            and values.accessoryMode ~= context.getSearchAccessoryMode(context)
        then
            changed = context.setSearchAccessoryMode(context,
                values.accessoryMode) or changed
        end
        return changed == true
    end,
    reset = function(context)
        return ResetElementPaths(context, { "searchBox.fontMode", "searchBox.sizeMode",
            "searchBox.outlineMode", "searchBox.font", "searchBox.textSize",
            "searchBox.outline", "searchBox.text", "searchBox.textMode",
            "searchBox.textOffsetX", "searchBox.textOffsetY",
            "searchBox.placeholderFontMode",
            "searchBox.placeholderSizeMode", "searchBox.placeholderOutlineMode",
            "searchBox.placeholderFont", "searchBox.placeholderSize",
            "searchBox.placeholderOutline", "searchBox.placeholderText",
            "searchBox.placeholderTextMode", "searchBox.background",
            "searchBox.backgroundMode", "searchBox.border", "searchBox.borderMode",
            "searchBox.borderSize", "searchBox.borderPadding",
            "searchBox.width", "searchBox.height",
            "searchBox.placeholderOffsetX", "searchBox.placeholderOffsetY" })
    end,
    resetSubset = function(context, keys)
        local changed = ResetMappedElementKeys(context, keys, searchResetPaths)
        if keys.accessoryMode and context.setSearchAccessoryMode then
            changed = context.setSearchAccessoryMode(context, "GROUPED") or changed
        end
        return changed == true
    end,
})

local windowAppearanceControls = {
    { type = "SLIDER", key = "backgroundOpacity", label = "Background opacity",
        min = 0, max = 1, step = 0.05, decimals = 2, order = 3 },
    CreateBorderGeometryControls(4),
    { type = "SLIDER", key = "headerOpacity", label = "Header opacity",
        min = 0, max = 1, step = 0.05, decimals = 2, order = 22 },
    { type = "CHECKBOX", key = "matchHeader",
        label = "Match header to background", order = 23 },
}
AddTypographyControls(windowAppearanceControls,
    { useGlobal = "headerUseGlobal", font = "headerFont",
        size = "headerTextSize", outline = "headerOutline" }, "Header", 20,
    { type = "COLOR", key = "headerText", modeKey = "headerTextMode",
        label = "Color" })
windowAppearanceControls[#windowAppearanceControls + 1] = {
    type = "SECTION", label = "Window", order = 1,
}
windowAppearanceControls[#windowAppearanceControls + 1] = {
    type = "COLOR_PAIR", order = 2,
    left = { type = "COLOR", key = "border", modeKey = "borderMode",
        label = "Border" },
    right = { type = "COLOR", key = "background", modeKey = "backgroundMode",
        label = "Background" },
}
windowAppearanceControls[#windowAppearanceControls + 1] = {
    type = "COLOR", key = "headerBackground", modeKey = "headerBackgroundMode",
    label = "Background", order = 21,
}
local windowResetPaths = {
    background = "window.background", backgroundOpacity = "window.background",
    backgroundMode = "window.backgroundMode", border = "window.border",
    borderMode = "window.borderMode", borderSize = "window.borderSize",
    borderPadding = "window.borderPadding",
    headerBackground = "window.header.background",
    headerOpacity = "window.header.background",
    headerBackgroundMode = "window.header.backgroundMode",
    matchHeader = "window.header.matchBackground",
    headerText = "window.header.text", headerTextMode = "window.header.textMode",
    headerFont = { "window.header.fontMode", "window.header.font" },
    headerTextSize = { "window.header.sizeMode", "window.header.textSize" },
    headerOutline = { "window.header.outlineMode", "window.header.outline" },
}
NSkin:RegisterOptionGroup("shared.windowAppearance", {
    controls = windowAppearanceControls,
    get = function(context)
        local style = NSkin:GetAppearanceStyle(
            "window", GetAppearanceWindowID(context), context.id)
        local values = { background = CopyColor(style.background),
            backgroundOpacity = style.background[4] or 1,
            border = CopyColor(style.border), borderMode = style.borderMode,
            borderSize = style.borderSize, borderPadding = style.borderPadding,
            headerBackground = CopyColor(style.header.background),
            headerText = CopyColor(style.header.text),
            headerTextMode = style.header.textMode,
            headerOpacity = style.header.background[4] or 1,
            backgroundMode = style.backgroundMode,
            headerBackgroundMode = style.header.backgroundMode,
            matchHeader = style.header.matchBackground == true }
        GetTypographyValues(values, style.header,
            { useGlobal = "headerUseGlobal", font = "headerFont",
                size = "headerTextSize", outline = "headerOutline" })
        return values
    end,
    set = function(context, values)
        local style = NSkin:GetAppearanceStyle(
            "window", GetAppearanceWindowID(context), context.id)
        local mapping = {
            ["window.backgroundMode"] = values.backgroundMode,
            ["window.border"] = values.border,
            ["window.borderMode"] = values.borderMode,
            ["window.borderSize"] = values.borderSize,
            ["window.borderPadding"] = values.borderPadding,
            ["window.header.backgroundMode"] = values.headerBackgroundMode,
            ["window.header.matchBackground"] = values.matchHeader,
            ["window.header.text"] = values.headerText,
            ["window.header.textMode"] = values.headerTextMode,
        }
        if values.background ~= nil or values.backgroundOpacity ~= nil then
            local background = CopyColor(values.background or style.background)
            background[4] = values.backgroundOpacity or background[4]
            mapping["window.background"] = background
        end
        if values.headerBackground ~= nil or values.headerOpacity ~= nil then
            local header = CopyColor(values.headerBackground or style.header.background)
            header[4] = values.headerOpacity or header[4]
            mapping["window.header.background"] = header
        end
        local changed = SetElementTypography(context, "window.header", values,
            { font = "headerFont", size = "headerTextSize",
                outline = "headerOutline" })
        for path, value in pairs(mapping) do
            if value ~= nil then changed = SetElementValue(context, path, value) or changed end
        end
        return changed == true
    end,
    reset = function(context)
        return ResetElementPaths(context, { "window.background", "window.backgroundMode",
            "window.border", "window.borderMode", "window.borderSize",
            "window.borderPadding",
            "window.header.background", "window.header.backgroundMode",
            "window.header.matchBackground",
            "window.header.text", "window.header.textMode",
            "window.header.fontMode",
            "window.header.sizeMode", "window.header.outlineMode",
            "window.header.font", "window.header.textSize", "window.header.outline" })
    end,
    resetSubset = function(context, keys)
        return ResetMappedElementKeys(context, keys, windowResetPaths)
    end,
})

local textAppearanceControls = {}
AddTypographyControls(textAppearanceControls,
    { useGlobal = "useGlobal", font = "font", size = "textSize", outline = "outline" },
    "Text", 1, { type = "COLOR", key = "color", modeKey = "colorMode",
        label = "Color" })
NSkin:RegisterOptionGroup("shared.textAppearance", {
    controls = textAppearanceControls,
    get = function(context)
        local style = NSkin:GetAppearanceStyle(
            "text", GetAppearanceWindowID(context), context.id)
        local values = { color = CopyColor(style.color), colorMode = style.colorMode }
        GetTypographyValues(values, style,
            { useGlobal = "useGlobal", font = "font", size = "textSize", outline = "outline" })
        return values
    end,
    set = function(context, values)
        local changed = SetElementTypography(context, "text", values,
            { font = "font", size = "textSize", outline = "outline" })
        if values.color ~= nil then
            changed = SetElementValue(context, "text.color", values.color) or changed
        end
        if values.colorMode ~= nil then
            changed = SetElementValue(context, "text.colorMode", values.colorMode) or changed
        end
        return changed == true
    end,
    reset = function(context)
        return ResetElementPaths(context, { "text.fontMode", "text.sizeMode",
            "text.outlineMode", "text.font", "text.textSize", "text.outline",
            "text.color", "text.colorMode" })
    end,
})

local headerAppearanceControls = {
    { type = "CHECKBOX", key = "underlineVisible", label = "Show underline", order = 11 },
    { type = "SLIDER", key = "underlineSize", label = "Underline size",
        min = 1, max = 6, step = 1, suffix = " px", order = 12 },
}
AddTypographyControls(headerAppearanceControls,
    { useGlobal = "useGlobal", font = "font", size = "textSize", outline = "outline" },
    "Header Text", 1, { type = "COLOR", key = "text", modeKey = "textMode",
        label = "Color" })
headerAppearanceControls[#headerAppearanceControls + 1] = {
    type = "SECTION", label = "Underline", order = 10,
}
headerAppearanceControls[#headerAppearanceControls + 1] = {
    type = "COLOR", key = "underline", modeKey = "underlineMode",
    label = "Color", order = 10.5,
}
local sectionHeaderResetPaths = {
    font = { "sectionHeader.fontMode", "sectionHeader.font" },
    textSize = { "sectionHeader.sizeMode", "sectionHeader.textSize" },
    outline = { "sectionHeader.outlineMode", "sectionHeader.outline" },
}
for _, key in ipairs({ "text", "textMode", "underlineVisible", "underlineSize",
    "underline", "underlineMode" }) do
    sectionHeaderResetPaths[key] = "sectionHeader." .. key
end
NSkin:RegisterOptionGroup("shared.sectionHeaderAppearance", {
    controls = headerAppearanceControls,
    get = function(context)
        local style = NSkin:GetAppearanceStyle(
            "sectionHeader", GetAppearanceWindowID(context), context.id)
        local values = { text = CopyColor(style.text), underline = CopyColor(style.underline),
            underlineVisible = style.underlineVisible, underlineSize = style.underlineSize,
            textMode = style.textMode, underlineMode = style.underlineMode }
        GetTypographyValues(values, style,
            { useGlobal = "useGlobal", font = "font", size = "textSize", outline = "outline" })
        return values
    end,
    set = function(context, values)
        local mapping = { text = "text", textMode = "textMode",
            underlineVisible = "underlineVisible", underlineSize = "underlineSize",
            underline = "underline", underlineMode = "underlineMode" }
        local changed = SetElementTypography(context, "sectionHeader", values,
            { font = "font", size = "textSize", outline = "outline" })
        for key, path in pairs(mapping) do
            if values[key] ~= nil then
                changed = SetElementValue(context, "sectionHeader." .. path, values[key]) or changed
            end
        end
        return changed == true
    end,
    reset = function(context)
        return ResetElementPaths(context, { "sectionHeader.fontMode",
            "sectionHeader.sizeMode", "sectionHeader.outlineMode",
            "sectionHeader.font", "sectionHeader.textSize", "sectionHeader.outline",
            "sectionHeader.text", "sectionHeader.textMode",
            "sectionHeader.underlineVisible", "sectionHeader.underlineSize",
            "sectionHeader.underline", "sectionHeader.underlineMode" })
    end,
    resetSubset = function(context, keys)
        return ResetMappedElementKeys(context, keys, sectionHeaderResetPaths)
    end,
})

NSkin:RegisterOptionGroup("shared.sectionHeaderPlacement", {
    controls = {
        { type = "SLIDER_PAIR", centerReset = true,
            resetGroup = true,
            resetTooltip = "Reset X and Y offsets",
            left = { key = "offsetX", label = "X offset", min = -200,
                max = 200, step = 0.1, decimals = 1, suffix = " px" },
            right = { key = "offsetY", label = "Y offset", min = -100,
                max = 100, step = 0.1, decimals = 1, suffix = " px" } },
    },
    get = function(context) return context.getSectionHeaderOffset(context) end,
    set = function(context, values)
        return context.setSectionHeaderOffset(context, values.offsetX, values.offsetY)
    end,
    reset = function(context) return context.resetSectionHeaderOffset(context) end,
})

local function FindControl(controls, controlType, key, label)
    for i = 1, #controls do
        local control = controls[i]
        if control.type == controlType
            and (not key or control.key == key)
            and (not label or control.label == label)
        then
            return control
        end
    end
end

local tabColors = FindControl(tabAppearanceControls, "COLOR_PAIR")
NSkin:RegisterOptionGroupSubset("shared.tabTextAppearance", "shared.tabAppearance", {
    FindControl(tabAppearanceControls, "TYPOGRAPHY", nil, "Tab Text"),
})
NSkin:RegisterOptionGroupSubset("shared.tabBorderAppearance", "shared.tabAppearance", {
    tabBorderGeometryControls,
    tabColors.left,
})
NSkin:RegisterOptionGroupSubset("shared.tabBackgroundAppearance", "shared.tabAppearance", {
    tabColors.right,
    FindControl(tabAppearanceControls, "COLOR", "selectedBackground"),
})
NSkin:RegisterOptionGroupSubset("shared.tabSurfaceAppearance", "shared.tabAppearance", {
    tabSizeControls,
    tabSpacingControl,
    tabBorderGeometryControls,
    { type = "COLOR_PAIR", order = 100,
        left = tabColors.left, right = tabColors.right },
    { type = "COLOR", key = "selectedBackground",
        modeKey = "selectedBackgroundMode", label = "Selected background",
        order = 101 },
})

local searchColors = FindControl(searchAppearanceControls, "COLOR_PAIR")
NSkin:RegisterOptionGroupSubset("shared.searchTextAppearance", "shared.searchAppearance", {
    FindControl(searchAppearanceControls, "TYPOGRAPHY", nil, "Search Text"),
    FindControl(searchAppearanceControls, "SLIDER_PAIR", nil, nil),
})
NSkin:RegisterOptionGroupSubset("shared.placeholderTextAppearance", "shared.searchAppearance", {
    FindControl(searchAppearanceControls, "TYPOGRAPHY", nil, "Placeholder Text"),
    searchAppearanceControls[4],
})
NSkin:RegisterOptionGroupSubset("shared.searchBoxAppearance", "shared.searchAppearance", {
    searchSizeControls,
    searchBorderGeometryControls,
    searchAccessoryControls,
    { type = "COLOR_PAIR", order = 100,
        left = searchColors.left, right = searchColors.right },
})

local windowColors = FindControl(windowAppearanceControls, "COLOR_PAIR")
NSkin:RegisterOptionGroupSubset("shared.windowBorderAppearance", "shared.windowAppearance", {
    FindControl(windowAppearanceControls, "SLIDER_PAIR", nil, nil),
    windowColors.left,
})
NSkin:RegisterOptionGroupSubset("shared.windowBackgroundAppearance", "shared.windowAppearance", {
    FindControl(windowAppearanceControls, "SLIDER", "backgroundOpacity"),
    windowColors.right,
})
NSkin:RegisterOptionGroupSubset("shared.windowSurfaceAppearance", "shared.windowAppearance", {
    FindControl(windowAppearanceControls, "SLIDER_PAIR", nil, nil),
    FindControl(windowAppearanceControls, "SLIDER", "backgroundOpacity"),
    FindControl(windowAppearanceControls, "CHECKBOX", "matchHeader"),
    { type = "COLOR_PAIR", order = 100,
        left = windowColors.left, right = windowColors.right },
})
NSkin:RegisterOptionGroupSubset("shared.windowHeaderAppearance", "shared.windowAppearance", {
    FindControl(windowAppearanceControls, "TYPOGRAPHY", nil, "Header"),
    FindControl(windowAppearanceControls, "SLIDER", "headerOpacity"),
    { type = "COLOR", key = "headerBackground",
        modeKey = "headerBackgroundMode", label = "Background", order = 100 },
})

NSkin:RegisterOptionGroupSubset("shared.headerTextAppearance",
    "shared.sectionHeaderAppearance", {
        FindControl(headerAppearanceControls, "TYPOGRAPHY", nil, "Header Text"),
    })
NSkin:RegisterOptionGroupSubset("shared.headerUnderlineAppearance",
    "shared.sectionHeaderAppearance", {
        FindControl(headerAppearanceControls, "CHECKBOX", "underlineVisible"),
        FindControl(headerAppearanceControls, "SLIDER", "underlineSize"),
        { type = "COLOR", key = "underline", modeKey = "underlineMode",
            label = "Color", order = 100 },
    })

end
