local _, NSkin = ...

local CONTENT_LEFT = 180
local CONTENT_TOP = -102
local CONTENT_BOTTOM = 52
local options
local definitionsByModule = {}
local definitionsByKey = {}
local standaloneDefinitions = {}

local optionGroups = {
    shared = { label = "Shared Elements", order = 10 },
    windows = { label = "Modules", order = 20 },
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

    local style = NSkin:GetStyle("window")
    NSkin:CreateFlatBackground(frame, "NSkinOptionsBackground", style.background, style.border)
    NSkin:SkinFlatButton(frame.CloseButton, "x", nil, nil, 16)
    if frame.CloseButton then
        frame.CloseButton:SetSize(22, 22)
        frame.CloseButton:ClearAllPoints()
        frame.CloseButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    end
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
        "Use the button beside each module tab to enable or disable it. "
        .. "Disabled modules install no hooks or events after reloading the UI."
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
        frame:SetResizeBounds(640, 420, maximumWidth, maximumHeight)
    else
        frame:SetMinResize(640, 420)
        frame:SetMaxResize(maximumWidth, maximumHeight)
    end
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:Hide()
    SkinOptionsWindow(frame)

    local logo = frame:CreateTexture(nil, "ARTWORK")
    logo:SetPoint("TOPLEFT", 14, -14)
    logo:SetSize(44, 44)
    logo:SetTexture(NSkin.mediaPath .. "Icon.tga")
    local addonName = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightLarge")
    addonName:SetPoint("LEFT", logo, "RIGHT", 4, -7)
    addonName:SetText("NSkin")
    local version = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    version:SetPoint("BOTTOMLEFT", addonName, "TOPRIGHT", 3, -2)
    local value = _G.C_AddOns and _G.C_AddOns.GetAddOnMetadata
        and _G.C_AddOns.GetAddOnMetadata(NSkin.addonName, "Version") or ""
    version:SetText(value ~= "" and ("v" .. value) or "")

    frame.navigationDivider = frame:CreateTexture(nil, "ARTWORK")
    frame.navigationDivider:SetPoint("TOPLEFT", CONTENT_LEFT - 14, -96)
    frame.navigationDivider:SetPoint("BOTTOMLEFT", CONTENT_LEFT - 14, 24)
    frame.navigationDivider:SetWidth(1)

    local contentScroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    contentScroll:SetPoint("TOPLEFT", frame, "TOPLEFT", CONTENT_LEFT, CONTENT_TOP)
    contentScroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -28, CONTENT_BOTTOM)
    contentScroll:EnableMouseWheel(true)
    contentScroll:SetScript("OnMouseWheel", function(self, delta)
        local value = self:GetVerticalScroll() - delta * 36
        self:SetVerticalScroll(math.max(0, math.min(self:GetVerticalScrollRange(), value)))
    end)
    local contentHost = CreateFrame("Frame", nil, contentScroll)
    contentHost:SetSize(math.max(1, contentScroll:GetWidth()), 1)
    contentScroll:SetScrollChild(contentHost)
    contentScroll:SetScript("OnSizeChanged", function(_, newWidth)
        contentHost:SetWidth(math.max(1, newWidth))
    end)

    local navigationScroll = CreateFrame(
        "ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate"
    )
    navigationScroll:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -96)
    navigationScroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMLEFT", CONTENT_LEFT - 28, 40)
    navigationScroll:EnableMouseWheel(true)
    navigationScroll:SetScript("OnMouseWheel", function(self, delta)
        local value = self:GetVerticalScroll() - delta * 32
        self:SetVerticalScroll(math.max(0, math.min(self:GetVerticalScrollRange(), value)))
    end)
    local navigationHost = CreateFrame("Frame", nil, navigationScroll)
    navigationHost:SetSize(132, 1)
    navigationScroll:SetScrollChild(navigationHost)

    local resizeGrip = CreateFrame("Button", nil, frame)
    resizeGrip:SetSize(18, 18)
    resizeGrip:SetPoint("BOTTOMRIGHT", -3, 3)
    for i = 1, 3 do
        local line = resizeGrip:CreateTexture(nil, "ARTWORK")
        line:SetColorTexture(0.55, 0.55, 0.55, 0.9)
        line:SetSize(2 + i * 3, 1)
        line:SetPoint("BOTTOMRIGHT", -2, 2 + (i - 1) * 3)
    end
    resizeGrip:SetScript("OnMouseDown", function(_, button)
        if button == "LeftButton" then frame:StartSizing("BOTTOMRIGHT") end
    end)
    resizeGrip:SetScript("OnMouseUp", function()
        frame:StopMovingOrSizing()
        NSkin:SetOptionsWindowSize(frame:GetWidth(), frame:GetHeight())
    end)

    local notice = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    notice:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", CONTENT_LEFT, 22)
    notice:SetText("Module changes require a UI reload.")
    notice:Hide()
    local reload = CreateFrame("Button", nil, frame)
    reload:SetSize(100, 24)
    reload:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -140, 14)
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
        info.page = page
        if page.ApplyTheme then page:ApplyTheme() end
        NSkin:ApplyGlobalTypography(page)
        return page
    end

    frame.navigationButtons = {}
    local navigationRow = 0
    local activeGroup
    local function AddNavigationButton(info, indent)
        local button = CreateFrame("Button", nil, navigationHost)
        button:SetSize(132, 16)
        button:SetPoint("TOPLEFT", indent and 15 or 0, -navigationRow * 16)
        button.label = button:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        button.label:SetPoint("LEFT")
        button.label:SetPoint("RIGHT", info.module and -22 or 0, 0)
        button.label:SetJustifyH("LEFT")
        button.label:SetText(info.label)
        button.selectedBackground = button:CreateTexture(nil, "BACKGROUND")
        button.selectedBackground:SetAllPoints()
        button.selectedBackground:Hide()
        button:SetScript("OnClick", function() frame:SelectOptionsPage(info.key) end)
        if info.module then
            local toggle = CreateFrame("Button", nil, button)
            toggle:SetSize(16, 16)
            toggle:SetPoint("RIGHT", -1, 0)
            toggle.check = toggle:CreateTexture(nil, "ARTWORK")
            toggle.check:SetPoint("TOPLEFT", 4, -4)
            toggle.check:SetPoint("BOTTOMRIGHT", -4, 4)
            toggle:SetScript("OnClick", function()
                NSkin:SetModuleEnabled(info.module, not NSkin:IsModuleEnabled(info.module))
                frame:RefreshModuleNavigation()
                notice:Show()
                reload:Show()
                if info.page and info.page.Refresh then info.page:Refresh() end
            end)
            info.moduleToggle = toggle
        end
        info.navigationButton = button
        frame.navigationButtons[#frame.navigationButtons + 1] = button
        navigationRow = navigationRow + 1
    end

    AddNavigationButton(byKey.general, false)
    for i = 2, #pages do
        local info = pages[i]
        if info.group ~= activeGroup then
            activeGroup = info.group
            local group = optionGroups[activeGroup]
            local heading = navigationHost:CreateFontString(
                nil, "ARTWORK", "GameFontHighlightSmall"
            )
            heading:SetPoint("TOPLEFT", 0, -navigationRow * 16)
            heading:SetText(group.label)
            navigationRow = navigationRow + 1
        end
        AddNavigationButton(info, true)
    end
    navigationHost:SetHeight(math.max(1, navigationRow * 16))

    function frame:RefreshModuleNavigation()
        local style = NSkin:GetStyle("options")
        for i = 1, #pages do
            local info = pages[i]
            if info.navigationButton then
                local enabled = not info.module or NSkin:IsModuleEnabled(info.module)
                info.navigationButton.label:SetTextColor(unpack(
                    enabled and style.enabledNavigationText or style.disabledNavigationText
                ))
                if info.moduleToggle then info.moduleToggle.check:SetShown(enabled) end
            end
        end
    end

    function frame:ApplyTheme()
        SkinOptionsWindow(self)
        self.navigationDivider:SetColorTexture(unpack(NSkin:GetStyle("window").header.divider))
        local optionsStyle = NSkin:GetStyle("options")
        local buttonStyle = NSkin:GetStyle("button")
        NSkin:SkinFlatButton(reload, "Reload UI", nil, nil, 12)
        for i = 1, #self.navigationButtons do
            self.navigationButtons[i].selectedBackground:SetColorTexture(
                unpack(optionsStyle.selectedNavigation)
            )
        end
        for i = 1, #pages do
            local toggle = pages[i].moduleToggle
            if toggle then
                NSkin:CreateFlatBackground(toggle, nil, buttonStyle.background,
                    NSkin:GetSharedBorderColor())
                toggle.check:SetColorTexture(unpack(optionsStyle.accent))
            end
        end
        self:RefreshModuleNavigation()
        for i = 1, #pages do
            local page = pages[i].page
            if page and page.ApplyStructureTheme then page:ApplyStructureTheme() end
            if page and page.ApplyTheme then page:ApplyTheme() end
        end
        NSkin:ApplyGlobalTypography(self)
    end
    function frame:SelectOptionsPage(key)
        local selectedInfo = byKey[key] or byKey.general
        local selectedPage = EnsurePage(selectedInfo)
        if not selectedPage then
            selectedInfo = byKey.general
            selectedPage = selectedInfo.page
        end
        self.selectedPageKey = selectedInfo.key
        contentHost.activePage = selectedPage
        contentHost:SetHeight(selectedPage.contentHeight or selectedPage:GetHeight() or 1)
        contentScroll:SetVerticalScroll(0)
        for i = 1, #pages do
            local info = pages[i]
            local selected = info == selectedInfo
            if info.page then info.page:SetShown(selected) end
            if info.navigationButton then info.navigationButton.selectedBackground:SetShown(selected) end
            if selected and selectedPage.Refresh then selectedPage:Refresh() end
        end
    end
    frame:SetScript("OnShow", function(self)
        self:ApplyTheme()
        self:SelectOptionsPage(self.selectedPageKey or "general")
    end)
    frame:SetScript("OnHide", function(self)
        self:StopMovingOrSizing()
        NSkin:SetOptionsWindowSize(self:GetWidth(), self:GetHeight())
    end)
    options = frame
    return frame
end

function NSkin:RefreshOptionsTheme()
    if options then options:ApplyTheme() end
end

function NSkin:ToggleOptions()
    local frame = CreateOptionsWindow()
    if frame:IsShown() then frame:Hide() else frame:Show() frame:Raise() end
end
