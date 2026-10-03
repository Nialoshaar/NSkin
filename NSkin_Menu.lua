local _, NSkin = ...

local THEME = NSkin.editorTheme
local SIDEBAR_WIDTH = 208
local HEADER_HEIGHT = 82
local FOOTER_HEIGHT = 54
local CONTENT_LEFT = SIDEBAR_WIDTH + 32
local CONTENT_TOP = -148
local CONTENT_BOTTOM = FOOTER_HEIGHT + 24
local options
local definitionsByModule = {}
local definitionsByKey = {}
local standaloneDefinitions = {}

local optionGroups = {
    shared = { label = "Shared Elements", order = 10 },
    windows = { label = "Windows", order = 20 },
}

function NSkin:RegisterOptionsPage(definition)
    if type(definition) ~= "table"
        or type(definition.builder) ~= "function"
    then
        return false
    end

    local key = definition.key or definition.module
    if type(key) ~= "string" or key == "" or definitionsByKey[key] then
        return false
    end
    definition.key = key

    if definition.module then
        if type(definition.module) ~= "string"
            or not self.moduleDefinitionByKey[definition.module]
            or definitionsByModule[definition.module]
        then
            return false
        end
        definitionsByModule[definition.module] = definition
    elseif type(definition.key) ~= "string"
        or definition.key == ""
        or type(definition.label) ~= "string"
        or not optionGroups[definition.group]
    then
        return false
    else
        standaloneDefinitions[#standaloneDefinitions + 1] = definition
    end

    definitionsByKey[definition.key] = definition
    return true
end

local pendingOptionsPages = NSkin.pendingOptionsPages
NSkin.pendingOptionsPages = nil
for i = 1, #(pendingOptionsPages or {}) do
    NSkin:RegisterOptionsPage(pendingOptionsPages[i])
end

local function SkinOptionsWindow(frame)
    if not frame.NSkinOptionsStripped then
        NSkin:HideTextureRegions(frame)
        if frame.Bg then frame.Bg:SetAlpha(0) frame.Bg:Hide() end
        if frame.TopTileStreaks then frame.TopTileStreaks:SetAlpha(0) frame.TopTileStreaks:Hide() end
        if frame.NineSlice then
            NSkin:HideTextureRegions(frame.NineSlice)
            frame.NineSlice:SetAlpha(0)
            frame.NineSlice:Hide()
        end
        if frame.Inset then
            NSkin:HideTextureRegions(frame.Inset)
            if frame.Inset.Bg then frame.Inset.Bg:Hide() end
            if frame.Inset.NineSlice then
                NSkin:HideTextureRegions(frame.Inset.NineSlice)
                frame.Inset.NineSlice:SetAlpha(0)
                frame.Inset.NineSlice:Hide()
            end
        end
        if frame.TitleText then frame.TitleText:Hide() end
        frame.NSkinOptionsStripped = true
    end

    NSkin:CreateFlatBackground(frame, "NSkinOptionsBackground", THEME.panel, THEME.border)
    NSkin:SkinFlatButton(frame.CloseButton, "x", THEME.background, THEME.border, 16)
    if frame.CloseButton then
        frame.CloseButton:SetSize(22, 22)
        frame.CloseButton:ClearAllPoints()
        frame.CloseButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -24, -29)
    end
end

local function MenuFont(label, size, color)
    label:SetFont(GameFontNormal:GetFont(), size, "")
    label:SetTextColor(unpack(color or THEME.text))
end

local function AddShellPanel(frame, color)
    local panel = frame:CreateTexture(nil, "BORDER", nil, -7)
    panel:SetColorTexture(unpack(color))
    return panel
end

local function AlignOptionsLogo(frame)
    local logo = frame.menuLogo
    if not logo then return end
    local left, top = frame:GetLeft(), frame:GetTop()
    if not left or not top then return end
    -- Snap screen-space bounds, rather than just the offsets: the window's
    -- origin can lie between pixels while dragging or after a scale change.
    local x = NSkin:SnapToPhysicalPixel(frame, left + 26) - left
    local y = NSkin:SnapToPhysicalPixel(frame, top - 5) - top
    local size = NSkin:SnapToPhysicalPixel(frame, 64)
    logo:ClearAllPoints()
    logo:SetPoint("TOPLEFT", frame, "TOPLEFT", x, y)
    logo:SetSize(size, size)
end

local function AlignOptionsGeometry(frame)
    if frame.aligningGeometry then return end
    local left, top = frame:GetLeft(), frame:GetTop()
    if not left or not top then return end
    frame.aligningGeometry = true
    local width = NSkin:SnapToPhysicalPixel(frame, frame:GetWidth())
    local height = NSkin:SnapToPhysicalPixel(frame, frame:GetHeight())
    if math.abs(width - frame:GetWidth()) > 0.0001
        or math.abs(height - frame:GetHeight()) > 0.0001 then
        frame:SetSize(width, height)
    end
    local x, y = NSkin:SnapToPhysicalPixel(frame, left), NSkin:SnapToPhysicalPixel(frame, top)
    if math.abs(x - left) > 0.0001 or math.abs(y - top) > 0.0001 then
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, y)
    end
    AlignOptionsLogo(frame)
    frame.aligningGeometry = nil
end

local function CreateGeneralPage(parent)
    local page = NSkin:CreateOptionsPage(parent)

    local title = page:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT")
    title:SetText(NSkin.displayName)
    local description = page:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    description:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -28)
    description:SetPoint("TOPRIGHT", page, "TOPRIGHT", 0, -28)
    description:SetJustifyH("LEFT")
    description:SetText(
        "Use the Windows page to enable or disable windows and choose their skin. "
        .. "Window changes require a UI reload."
    )
    page:SetContentHeight(90)
    return page
end

local function CreateEmptyModulePage(parent, info)
    local page = NSkin:CreateOptionsPage(parent)

    local title = page:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT")
    title:SetText(info.label)
    local description = page:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    description:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    description:SetText("This module has no additional settings.")
    page:SetContentHeight(80)
    return page
end

local function CreateOptionsWindow()
    if options then return options end
    local frame = CreateFrame("Frame", "NSkinOptions", UIParent, "BasicFrameTemplateWithInset")
    local width, height, maximumWidth, maximumHeight = NSkin:GetOptionsWindowSize()
    frame:SetSize(width, height)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:SetResizable(true)
    if frame.SetResizeBounds then
        frame:SetResizeBounds(720, 420, maximumWidth, maximumHeight)
    else
        frame:SetMinResize(720, 420)
        frame:SetMaxResize(maximumWidth, maximumHeight)
    end
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        AlignOptionsGeometry(self)
    end)
    frame:SetScript("OnSizeChanged", AlignOptionsGeometry)
    frame:Hide()
    SkinOptionsWindow(frame)

    local sidebar = AddShellPanel(frame, THEME.sidebar)
    sidebar:SetPoint("TOPLEFT", 1, -HEADER_HEIGHT)
    sidebar:SetPoint("BOTTOMLEFT", 1, 1)
    sidebar:SetWidth(SIDEBAR_WIDTH - 1)
    -- Header/footer use opposite-edge anchors so resizing preserves their height.
    local header = AddShellPanel(frame, THEME.background)
    header:SetPoint("TOPLEFT", 1, -1)
    header:SetPoint("TOPRIGHT", -1, -1)
    header:SetHeight(HEADER_HEIGHT - 1)
    local footer = AddShellPanel(frame, THEME.background)
    footer:SetPoint("BOTTOMLEFT", SIDEBAR_WIDTH, 1)
    footer:SetPoint("BOTTOMRIGHT", -1, 1)
    footer:SetHeight(FOOTER_HEIGHT - 1)
    NSkin:CreateEditorDivider(frame, frame, false, -HEADER_HEIGHT, 1, 1)
    NSkin:CreateEditorDivider(frame, footer, false, 0)

    local logo = frame:CreateTexture(nil, "ARTWORK")
    logo:SetPoint("TOPLEFT", 26, -5)
    logo:SetSize(64, 64)
    logo:SetTexture(NSkin.mediaPath .. "logo.png", "CLAMP", "CLAMP", "LINEAR")
    NSkin:ConfigureOwnedPixelTexture(logo)
    frame.menuLogo = logo
    AlignOptionsLogo(frame)
    NSkin:RegisterPhysicalPixelRefresh(frame, "optionsMenuLogo", AlignOptionsLogo)
    local addonName = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightLarge")
    addonName:SetPoint("LEFT", logo, "RIGHT", 12, 0)
    addonName:SetText("NSkin")
    MenuFont(addonName, 22)
    local version = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    version:SetPoint("LEFT", addonName, "RIGHT", 14, 0)
    MenuFont(version, 12, THEME.muted)
    local value = _G.C_AddOns and _G.C_AddOns.GetAddOnMetadata
        and _G.C_AddOns.GetAddOnMetadata(NSkin.addonName, "Version") or ""
    version:SetText(value ~= "" and ("v" .. value) or "")

    frame.navigationDivider = NSkin:CreateEditorDivider(frame, frame, true,
        SIDEBAR_WIDTH, HEADER_HEIGHT, 1)

    local breadcrumb = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    breadcrumb:SetPoint("TOPLEFT", CONTENT_LEFT, -110)
    breadcrumb:SetPoint("TOPRIGHT", -32, -110)
    breadcrumb:SetJustifyH("LEFT")
    MenuFont(breadcrumb, 12, THEME.muted)

    local contentScroll = CreateFrame("ScrollFrame", nil, frame)
    contentScroll:SetPoint("TOPLEFT", frame, "TOPLEFT", CONTENT_LEFT, CONTENT_TOP)
    contentScroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -40, CONTENT_BOTTOM)
    contentScroll:EnableMouseWheel(true)
    contentScroll:SetScript("OnMouseWheel", function(self, delta)
        local value = self:GetVerticalScroll() - delta * 36
        self:SetVerticalScroll(math.max(0, math.min(self:GetVerticalScrollRange(), value)))
    end)
    local contentHost = CreateFrame("Frame", nil, contentScroll)
    contentHost.optionsTheme = THEME
    contentHost:SetSize(math.max(1, contentScroll:GetWidth()), 1)
    contentScroll:SetScrollChild(contentHost)
    contentScroll:SetScript("OnSizeChanged", function(_, newWidth)
        contentHost:SetWidth(math.max(1, newWidth))
    end)
    NSkin:CreateEditorScrollBar(contentScroll, frame, 14)

    local navigationScroll = CreateFrame(
        "ScrollFrame", nil, frame
    )
    navigationScroll:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -HEADER_HEIGHT - 20)
    navigationScroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMLEFT", SIDEBAR_WIDTH - 30, 24)
    navigationScroll:EnableMouseWheel(true)
    navigationScroll:SetScript("OnMouseWheel", function(self, delta)
        local value = self:GetVerticalScroll() - delta * 32
        self:SetVerticalScroll(math.max(0, math.min(self:GetVerticalScrollRange(), value)))
    end)
    local navigationHost = CreateFrame("Frame", nil, navigationScroll)
    navigationHost:SetSize(SIDEBAR_WIDTH - 46, 1)
    navigationScroll:SetScrollChild(navigationHost)
    NSkin:CreateEditorScrollBar(navigationScroll, frame, 10)

    local resizeGrip = CreateFrame("Button", nil, frame)
    resizeGrip:SetSize(18, 18)
    resizeGrip:SetPoint("BOTTOMRIGHT", -3, 3)
    for i = 1, 3 do
        local line = resizeGrip:CreateTexture(nil, "ARTWORK")
        line:SetColorTexture(unpack(THEME.muted))
        line:SetSize(2 + i * 3, 1)
        line:SetPoint("BOTTOMRIGHT", -2, 2 + (i - 1) * 3)
    end
    resizeGrip:SetScript("OnMouseDown", function(_, button)
        if button == "LeftButton" then frame:StartSizing("BOTTOMRIGHT") end
    end)
    resizeGrip:SetScript("OnMouseUp", function()
        frame:StopMovingOrSizing()
        AlignOptionsGeometry(frame)
        NSkin:SetOptionsWindowSize(frame:GetWidth(), frame:GetHeight())
    end)

    local notice = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    notice:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", CONTENT_LEFT, 22)
    notice:SetText("Module changes require a UI reload.")
    MenuFont(notice, 12, THEME.muted)
    notice:Hide()
    local reload = CreateFrame("Button", nil, frame)
    reload:SetSize(112, 30)
    reload:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -28, 12)
    reload:SetScript("OnClick", function() _G.ReloadUI() end)
    reload:Hide()

    local modulePages = {}
    for i = 1, #NSkin.moduleDefinitions do
        local moduleDefinition = NSkin.moduleDefinitions[i]
        local registered = definitionsByModule[moduleDefinition.key]
        local group = optionGroups[moduleDefinition.optionsGroup]
            and moduleDefinition.optionsGroup or "windows"
        modulePages[#modulePages + 1] = {
            key = moduleDefinition.key,
            label = moduleDefinition.label,
            group = group,
            order = tonumber(moduleDefinition.optionsOrder) or 100,
            module = moduleDefinition.key,
            builder = registered and registered.builder,
        }
    end
    for i = 1, #standaloneDefinitions do
        local definition = standaloneDefinitions[i]
        modulePages[#modulePages + 1] = {
            key = definition.key,
            label = definition.label,
            group = definition.group,
            order = tonumber(definition.order) or 100,
            builder = definition.builder,
            module = definition.moduleOwner,
        }
    end
    table.sort(modulePages, function(left, right)
        local leftGroup = optionGroups[left.group]
        local rightGroup = optionGroups[right.group]
        if leftGroup.order ~= rightGroup.order then return leftGroup.order < rightGroup.order end
        if left.order ~= right.order then return left.order < right.order end
        return left.label < right.label
    end)

    local pages = {
        { key = "general", label = "General", page = CreateGeneralPage(contentHost) },
    }
    local byKey = { general = pages[1] }
    for i = 1, #modulePages do
        local info = modulePages[i]
        pages[#pages + 1] = info
        byKey[info.key] = info
    end
    local windows = {}
    for _, info in ipairs(modulePages) do
        if info.group == "windows" then windows[#windows + 1] = info end
    end
    local windowsInfo = { key = "windows", label = "Windows", group = "shared",
        builder = function(parent) return NSkin:BuildWindowsLibrary(parent, windows) end }
    byKey.windows = windowsInfo
    pages[#pages + 1] = windowsInfo

    local function EnsurePage(info)
        if info.page then return info.page end

        local page
        if info.builder then
            page = info.builder(contentHost)
        else
            page = CreateEmptyModulePage(contentHost, info)
        end
        if not page then return nil end
        page:Hide()
        page.onModuleConfigurationChanged = function()
            notice:Show()
            reload:Show()
        end
        page.openWindowSettings = function(key) frame:SelectOptionsPage(key) end
        info.page = page
        if page.ApplyStructureAppearance then page:ApplyStructureAppearance() end
        if page.ApplyAppearance then page:ApplyAppearance() end
        NSkin:ApplyGlobalTypography(page)
        page.nskinAppearanceRevision = frame.appearanceRevision
        return page
    end

    frame.navigationButtons = {}
    local navigationRow = 0
    local activeGroup
    local function AddNavigationButton(info, indent)
        local button = CreateFrame("Button", nil, navigationHost)
        button:SetSize(SIDEBAR_WIDTH - 46, 34)
        button:SetPoint("TOPLEFT", 0, -navigationRow)
        button.label = button:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        button.label:SetPoint("LEFT", indent and 12 or 10, 0)
        button.label:SetPoint("RIGHT", info.module and -28 or -10, 0)
        button.label:SetJustifyH("LEFT")
        button.label:SetText(info.label)
        MenuFont(button.label, 13)
        button.selectedBackground = button:CreateTexture(nil, "BACKGROUND")
        button.selectedBackground:SetAllPoints()
        button.selectedBackground:Hide()
        button:SetScript("OnClick", function() frame:SelectOptionsPage(info.key) end)
        info.navigationButton = button
        frame.navigationButtons[#frame.navigationButtons + 1] = button
        navigationRow = navigationRow + 38
    end

    AddNavigationButton(byKey.general, false)
    for i = 2, #pages do
        local info = pages[i]
        if info.group ~= "windows" and info ~= windowsInfo then
            if info.group ~= activeGroup then
                activeGroup = info.group
                local group = optionGroups[activeGroup]
                local heading = navigationHost:CreateFontString(
                    nil, "ARTWORK", "GameFontHighlightSmall"
                )
                heading:SetPoint("TOPLEFT", 10, -navigationRow - 14)
                heading:SetText(group.label)
                MenuFont(heading, 11, THEME.muted)
                navigationRow = navigationRow + 40
            end
            AddNavigationButton(info, true)
            if info.key == "appearance" then AddNavigationButton(windowsInfo, true) end
        end
    end
    navigationHost:SetHeight(math.max(1, navigationRow))

    function frame:RefreshModuleNavigation()
        local selected = byKey[self.selectedPageKey]
        local selectedKey = selected and selected.group == "windows" and "windows" or self.selectedPageKey
        for i = 1, #pages do
            local info = pages[i]
            if info.navigationButton then
                local enabled = not info.module or NSkin:IsModuleEnabled(info.module)
                NSkin:SetFontStringColor(info.navigationButton.label, unpack(
                    not enabled and THEME.muted
                        or (selectedKey == info.key and THEME.accent or THEME.text)
                ))
            end
        end
    end

    function frame:ApplyAppearance(change)
        self.appearanceRevision = (self.appearanceRevision or 0) + 1
        local revision = self.appearanceRevision
        local targeted = change and change.scope == "type"
        local styleName = targeted and change.style
        local refreshChrome = not targeted or styleName == "window"
            or styleName == "button" or styleName == "options"
        if refreshChrome then
            SkinOptionsWindow(self)
            NSkin:SetOwnedTextureColor(self.navigationDivider,
                unpack(THEME.border))
            NSkin:SkinFlatButton(reload, "Reload UI", THEME.accent, THEME.accent, 12)
            for i = 1, #self.navigationButtons do
                NSkin:SetOwnedTextureColor(
                    self.navigationButtons[i].selectedBackground,
                    unpack(THEME.selected))
            end
            self:RefreshModuleNavigation()
        end
        for i = 1, #pages do
            local page = pages[i].page
            if page and (not targeted or page == contentHost.activePage) then
                if page.ApplyStructureAppearance then page:ApplyStructureAppearance() end
                if page.ApplyAppearance then page:ApplyAppearance() end
                page.nskinAppearanceRevision = revision
            end
        end
        if not targeted then NSkin:ApplyGlobalTypography(self) end
        MenuFont(addonName, 22)
        MenuFont(version, 12, THEME.muted)
        MenuFont(breadcrumb, 12, THEME.muted)
        MenuFont(notice, 12, THEME.muted)
        for i = 1, #self.navigationButtons do
            local button = self.navigationButtons[i]
            MenuFont(button.label, 13)
        end
        self:RefreshModuleNavigation()
    end
    function frame:SelectOptionsPage(key)
        local selectedInfo = byKey[key] or byKey.general
        local selectedPage = EnsurePage(selectedInfo)
        if not selectedPage then
            selectedInfo = byKey.general
            selectedPage = selectedInfo.page
        end
        self.selectedPageKey = selectedInfo.key
        local group = selectedInfo.group and optionGroups[selectedInfo.group]
        local function RefreshBreadcrumb()
            breadcrumb:SetText("NSkin  /  " .. (group and (group.label .. "  /  ") or "")
                .. selectedInfo.label .. (selectedPage.navigationSuffix or ""))
        end
        selectedPage.onNavigationChanged = function()
            if contentHost.activePage == selectedPage then
                RefreshBreadcrumb()
                contentScroll:SetVerticalScroll(0)
            end
        end
        RefreshBreadcrumb()
        contentHost.activePage = selectedPage
        contentHost:SetHeight(selectedPage.contentHeight or selectedPage:GetHeight() or 1)
        contentScroll:SetVerticalScroll(0)
        for i = 1, #pages do
            local info = pages[i]
            local selected = info == selectedInfo
            if info.page then info.page:SetShown(selected) end
            if info.navigationButton then
                info.navigationButton.selectedBackground:SetShown(selected
                    or (info == windowsInfo and selectedInfo.group == "windows"))
            end
            if selected and selectedPage.Refresh then selectedPage:Refresh() end
        end
        if selectedPage.nskinAppearanceRevision ~= self.appearanceRevision then
            if selectedPage.ApplyStructureAppearance then
                selectedPage:ApplyStructureAppearance()
            end
            if selectedPage.ApplyAppearance then selectedPage:ApplyAppearance() end
            NSkin:ApplyGlobalTypography(selectedPage)
            selectedPage.nskinAppearanceRevision = self.appearanceRevision
        end
        self:RefreshModuleNavigation()
    end
    frame:SetScript("OnShow", function(self)
        AlignOptionsGeometry(self)
        self:ApplyAppearance()
        self:SelectOptionsPage(self.selectedPageKey or "general")
    end)
    frame:SetScript("OnHide", function(self)
        self:StopMovingOrSizing()
        NSkin:SetOptionsWindowSize(self:GetWidth(), self:GetHeight())
    end)
    options = frame
    return frame
end

function NSkin:RefreshOptionsAppearance(change)
    if options then options:ApplyAppearance(change) end
end

function NSkin:ToggleOptions()
    local frame = CreateOptionsWindow()
    if frame:IsShown() then frame:Hide() else frame:Show() frame:Raise() end
end
