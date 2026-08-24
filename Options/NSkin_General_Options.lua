local _, NSkin = ...

local CONTENT_LEFT = 180
local NAV_TOP = -102
local options
local definitions = {}
local definitionsByKey = {}

local optionGroups = {
    shared = { label = "Shared Elements", order = 10 },
    windows = { label = "Windows", order = 20 },
}

function NSkin:RegisterOptionsPage(definition)
    if type(definition) ~= "table"
        or type(definition.key) ~= "string"
        or definition.key == ""
        or definition.key == "general"
        or type(definition.label) ~= "string"
        or definition.label == ""
        or type(definition.group) ~= "string"
        or not optionGroups[definition.group]
        or type(definition.builder) ~= "function"
        or definitionsByKey[definition.key]
    then
        return false
    end

    definition.order = tonumber(definition.order) or 100
    definitions[#definitions + 1] = definition
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

local function CreateGeneralPage(frame)
    local page = CreateFrame("Frame", nil, frame)
    page:SetAllPoints(frame)

    local title = page:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", frame, "TOPLEFT", CONTENT_LEFT, -102)
    title:SetText("Modules")
    local description = page:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    description:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    description:SetText("Disabled modules install no hooks or events after reloading the UI.")

    local notice = page:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    notice:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", CONTENT_LEFT, 22)
    notice:SetText("Module changes require a UI reload.")
    notice:Hide()
    local reload = CreateFrame("Button", nil, page)
    reload:SetSize(100, 24)
    reload:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -20, 14)
    reload:SetScript("OnClick", function() _G.ReloadUI() end)
    reload:Hide()

    page.rows = {}
    for i = 1, #NSkin.moduleDefinitions do
        local definition = NSkin.moduleDefinitions[i]
        local row = CreateFrame("CheckButton", nil, page)
        row:SetSize(260, 22)
        row:SetPoint("TOPLEFT", description, "BOTTOMLEFT", 0, -12 - (i - 1) * 30)
        row.moduleKey = definition.key
        row.box = CreateFrame("Frame", nil, row)
        row.box:SetSize(18, 18)
        row.box:SetPoint("LEFT")
        row.check = row.box:CreateTexture(nil, "ARTWORK")
        row.check:SetPoint("TOPLEFT", 4, -4)
        row.check:SetPoint("BOTTOMRIGHT", -4, 4)
        local label = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        label:SetPoint("LEFT", row.box, "RIGHT", 8, 0)
        label:SetText(definition.label)
        row:SetScript("OnClick", function(self)
            local enabled = self:GetChecked() == true
            NSkin:SetModuleEnabled(self.moduleKey, enabled)
            self.check:SetShown(enabled)
            notice:Show()
            reload:Show()
        end)
        page.rows[i] = row
    end

    function page:ApplyTheme()
        local buttonStyle = NSkin:GetStyle("button")
        local optionsStyle = NSkin:GetStyle("options")
        NSkin:SkinFlatButton(reload, "Reload UI", nil, nil, 12)
        for i = 1, #self.rows do
            local row = self.rows[i]
            NSkin:CreateFlatBackground(row.box, nil, buttonStyle.background, buttonStyle.border)
            row.check:SetColorTexture(unpack(optionsStyle.accent))
        end
    end
    function page:Refresh()
        self:ApplyTheme()
        for i = 1, #self.rows do
            local row = self.rows[i]
            local enabled = NSkin:IsModuleEnabled(row.moduleKey)
            row:SetChecked(enabled)
            row.check:SetShown(enabled)
        end
    end
    page:ApplyTheme()
    return page
end

local function CreateOptionsWindow()
    if options then return options end
    local frame = CreateFrame("Frame", "NSkinOptions", UIParent, "BasicFrameTemplateWithInset")
    frame:SetSize(700, 460)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:Hide()
    frame.NSkinContentLeft = CONTENT_LEFT
    SkinOptionsWindow(frame)

    local logo = frame:CreateTexture(nil, "ARTWORK")
    logo:SetPoint("TOPLEFT", 14, -14)
    logo:SetSize(44, 44)
    logo:SetTexture("Interface\\AddOns\\NialoSkin\\Media\\Icon.tga")
    local addonName = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightLarge")
    addonName:SetPoint("LEFT", logo, "RIGHT", 4, -7)
    addonName:SetText("NSkin")
    local version = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    version:SetPoint("BOTTOMLEFT", addonName, "TOPRIGHT", 3, -2)
    local value = _G.C_AddOns and _G.C_AddOns.GetAddOnMetadata
        and _G.C_AddOns.GetAddOnMetadata(NSkin.name, "Version") or ""
    version:SetText(value ~= "" and ("v" .. value) or "")

    frame.navigationDivider = frame:CreateTexture(nil, "ARTWORK")
    frame.navigationDivider:SetPoint("TOPLEFT", CONTENT_LEFT - 14, -96)
    frame.navigationDivider:SetPoint("BOTTOMLEFT", CONTENT_LEFT - 14, 24)
    frame.navigationDivider:SetWidth(1)

    table.sort(definitions, function(left, right)
        local leftGroup = optionGroups[left.group]
        local rightGroup = optionGroups[right.group]
        if leftGroup.order ~= rightGroup.order then return leftGroup.order < rightGroup.order end
        if left.order ~= right.order then return left.order < right.order end
        return left.label < right.label
    end)

    local pages = { { key = "general", label = "General", page = CreateGeneralPage(frame) } }
    local byKey = { general = pages[1] }
    for i = 1, #definitions do
        local definition = definitions[i]
        local page = definition.builder(frame)
        if page then
            page:Hide()
            local info = {
                key = definition.key,
                label = definition.label,
                group = definition.group,
                page = page,
            }
            pages[#pages + 1] = info
            byKey[definition.key] = info
        end
    end

    frame.navigationButtons = {}
    local navigationRow = 0
    local activeGroup
    local function AddNavigationButton(info, indent)
        local button = CreateFrame("Button", nil, frame)
        button:SetSize(132, 16)
        button:SetPoint("TOPLEFT", indent and 27 or 12, NAV_TOP - navigationRow * 16)
        button:SetNormalFontObject("GameFontHighlightSmall")
        button:SetHighlightFontObject("GameFontHighlightSmall")
        button:SetText(info.label)
        button:GetFontString():SetJustifyH("LEFT")
        button.selectedBackground = button:CreateTexture(nil, "BACKGROUND")
        button.selectedBackground:SetAllPoints()
        button.selectedBackground:Hide()
        button:SetScript("OnClick", function() frame:SelectOptionsPage(info.key) end)
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
            local heading = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
            heading:SetPoint("TOPLEFT", 12, NAV_TOP - navigationRow * 16)
            heading:SetText(group.label)
            navigationRow = navigationRow + 1
        end
        AddNavigationButton(info, true)
    end

    function frame:ApplyTheme()
        SkinOptionsWindow(self)
        self.navigationDivider:SetColorTexture(unpack(NSkin:GetStyle("window").header.divider))
        local selectedColor = NSkin:GetStyle("options").selectedNavigation
        for i = 1, #self.navigationButtons do
            self.navigationButtons[i].selectedBackground:SetColorTexture(unpack(selectedColor))
        end
        for i = 1, #pages do
            if pages[i].page.ApplyTheme then pages[i].page:ApplyTheme() end
        end
    end
    function frame:SelectOptionsPage(key)
        self.selectedPageKey = key
        for i = 1, #pages do
            local info = pages[i]
            local selected = info.key == key
            info.page:SetShown(selected)
            if info.navigationButton then info.navigationButton.selectedBackground:SetShown(selected) end
            if selected and info.page.Refresh then info.page:Refresh() end
        end
    end
    frame:SetScript("OnShow", function(self)
        self:ApplyTheme()
        self:SelectOptionsPage(self.selectedPageKey or "general")
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
