local _, NSkin = ...

local WINDOW_WIDTH = 560
local WINDOW_HEIGHT = 360
local ROW_HEIGHT = 26
local CONTROL_BACKGROUND = { 0.04, 0.04, 0.04, 0.90 }
local CONTROL_BACKGROUND_SELECTED = { 0.16, 0.16, 0.16, 0.95 }
local DIVIDER_COLOR = { 0.45, 0.45, 0.45, 1 }

local options
local optionPageDefinitions = {}

local function SkinOptionsWindow(frame)
    if frame.Bg then
        frame.Bg:SetAlpha(0)
        frame.Bg:Hide()
    end
    if frame.TopTileStreaks then
        frame.TopTileStreaks:SetAlpha(0)
        frame.TopTileStreaks:Hide()
    end
    if frame.NineSlice then frame.NineSlice:Hide() end
    if frame.Inset then
        if frame.Inset.Bg then frame.Inset.Bg:Hide() end
        if frame.Inset.NineSlice then frame.Inset.NineSlice:Hide() end
    end

    NSkin:CreateFlatBackground(frame, "NSkinOptionsBackground",
        { 0, 0, 0, 0.80 }, DIVIDER_COLOR)

    local titleBackground = frame:CreateTexture(nil, "BACKGROUND", nil, 7)
    titleBackground:SetPoint("TOPLEFT", 1, -1)
    titleBackground:SetPoint("TOPRIGHT", -1, -1)
    titleBackground:SetHeight(21)
    titleBackground:SetColorTexture(unpack(CONTROL_BACKGROUND))
    frame.NSkinTitleBackground = titleBackground

    if frame.TitleText then frame.TitleText:SetTextColor(1, 1, 1) end

    local closeButton = frame.CloseButton
    NSkin:SkinFlatButton(closeButton, "x", CONTROL_BACKGROUND, DIVIDER_COLOR, 16)
    if closeButton then
        closeButton:SetSize(22, 22)
        closeButton:ClearAllPoints()
        closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    end
end

function NSkin:RegisterOptionsPage(key, label, builder)
    if type(key) ~= "string" or type(label) ~= "string" or type(builder) ~= "function" then
        return false
    end

    optionPageDefinitions[#optionPageDefinitions + 1] = {
        key = key,
        label = label,
        builder = builder,
    }
    return true
end

local builtInTextures = {
    {
        name = "Naowh Gradient",
        path = "Interface\\AddOns\\NaowhUI_Media\\Shared\\Textures\\NaowhGradient.tga",
        priority = 1,
    },
    {
        name = "Blizzard Flat",
        path = "Interface\\Buttons\\WHITE8X8",
        priority = 2,
    },
}

local function CollectTextures()
    local byPath = {}
    local textures = {}

    local function AddTexture(name, path, priority)
        if type(name) ~= "string" or type(path) ~= "string" or path == "" or byPath[path] then
            return
        end

        local entry = { name = name, path = path, priority = priority or 100 }
        byPath[path] = entry
        textures[#textures + 1] = entry
    end

    for i = 1, #builtInTextures do
        local texture = builtInTextures[i]
        AddTexture(texture.name, texture.path, texture.priority)
    end

    if _G.LibStub then
        local ok, sharedMedia = pcall(function()
            return _G.LibStub("LibSharedMedia-3.0", true)
        end)

        if ok and sharedMedia then
            local registered = sharedMedia:HashTable("statusbar")
            if registered then
                for name, path in pairs(registered) do AddTexture(name, path) end
            end
        end
    end

    table.sort(textures, function(left, right)
        if left.priority ~= right.priority then return left.priority < right.priority end
        return left.name:lower() < right.name:lower()
    end)

    return textures
end

local function FindTextureName(textures, path)
    for i = 1, #textures do
        if textures[i].path == path then return textures[i].name end
    end
    return "Custom texture"
end

local function CreateOptionsWindow()
    if options then return options end

    local frame = CreateFrame(
        "Frame",
        "NSkinTextureOptions",
        UIParent,
        "BasicFrameTemplateWithInset"
    )
    frame:SetSize(WINDOW_WIDTH, WINDOW_HEIGHT)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:Hide()

    frame.TitleText:SetText("Nialo Skin")
    SkinOptionsWindow(frame)

    local progressPage = CreateFrame("Frame", nil, frame)
    progressPage:SetAllPoints(frame)

    local label = progressPage:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    label:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -76)
    label:SetText("Texture")

    local selected = CreateFrame("Button", nil, progressPage, "UIPanelButtonTemplate")
    selected:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -8)
    selected:SetPoint("RIGHT", frame, "RIGHT", -18, 0)
    selected:SetHeight(28)
    selected:SetText("Naowh Gradient")
    frame.selectedButton = selected

    local listBorder = CreateFrame("Frame", nil, progressPage, "BackdropTemplate")
    listBorder:SetPoint("TOPLEFT", selected, "BOTTOMLEFT", 0, -6)
    listBorder:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -18, 52)
    listBorder:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    listBorder:SetBackdropColor(0.035, 0.055, 0.065, 0.98)
    listBorder:SetBackdropBorderColor(0.25, 0.32, 0.35, 1)

    local scrollFrame = CreateFrame("ScrollFrame", nil, listBorder, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 4, -4)
    scrollFrame:SetPoint("BOTTOMRIGHT", -27, 4)
    scrollFrame:EnableMouseWheel(true)

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(1, 1)
    scrollFrame:SetScrollChild(content)
    frame.listContent = content
    frame.scrollFrame = scrollFrame

    scrollFrame:SetScript("OnSizeChanged", function(self, width)
        content:SetWidth(width)
    end)
    scrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local range = self:GetVerticalScrollRange()
        local value = self:GetVerticalScroll() - delta * ROW_HEIGHT * 3
        self:SetVerticalScroll(math.max(0, math.min(range, value)))
    end)

    function frame:RebuildTextureList()
        if self.rows then
            for i = 1, #self.rows do self.rows[i]:Hide() end
        end

        self.rows = self.rows or {}
        self.textures = CollectTextures()
        content:SetHeight(math.max(1, #self.textures * ROW_HEIGHT))

        for i = 1, #self.textures do
            local texture = self.textures[i]
            local row = self.rows[i]

            if not row then
                row = CreateFrame("Button", nil, content)
                row:SetHeight(ROW_HEIGHT)
                row:SetPoint("LEFT", 0, 0)
                row:SetPoint("RIGHT", 0, 0)

                local background = row:CreateTexture(nil, "BACKGROUND")
                background:SetAllPoints()
                background:SetColorTexture(0.07, 0.10, 0.11, 0.94)
                row.background = background

                local highlight = row:CreateTexture(nil, "HIGHLIGHT")
                highlight:SetAllPoints()
                highlight:SetColorTexture(0.38, 0.42, 0.43, 0.75)

                local preview = row:CreateTexture(nil, "ARTWORK")
                preview:SetPoint("LEFT", 6, 0)
                preview:SetSize(145, 16)
                row.preview = preview

                local name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
                name:SetPoint("LEFT", preview, "RIGHT", 12, 0)
                name:SetPoint("RIGHT", -8, 0)
                name:SetJustifyH("LEFT")
                row.name = name

                row:SetScript("OnClick", function(self)
                    NSkin:SetStatusBarTexture(self.texturePath)
                    selected:SetText(self.textureName)
                    NSkin:SetFlatButtonLabel(selected, self.textureName, 12)
                    NSkin:Print("progress bar texture set to " .. self.textureName .. ".")
                end)

                self.rows[i] = row
            end

            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -(i - 1) * ROW_HEIGHT)
            row:SetPoint("RIGHT", content, "RIGHT", 0, 0)
            row.preview:SetTexture(texture.path)
            row.name:SetText(texture.name)
            row.textureName = texture.name
            row.texturePath = texture.path
            row.background:SetColorTexture(
                texture.path == NSkin:GetStatusBarTexture() and 0.12 or 0.07,
                texture.path == NSkin:GetStatusBarTexture() and 0.20 or 0.10,
                texture.path == NSkin:GetStatusBarTexture() and 0.23 or 0.11,
                0.94
            )
            row:Show()
        end

        local selectedName = FindTextureName(self.textures, NSkin:GetStatusBarTexture())
        selected:SetText(selectedName)
        NSkin:SetFlatButtonLabel(selected, selectedName, 12)
        scrollFrame:SetVerticalScroll(0)
    end

    selected:SetScript("OnClick", function()
        if listBorder:IsShown() then
            listBorder:Hide()
        else
            frame:RebuildTextureList()
            listBorder:Show()
        end
    end)

    local reset = CreateFrame("Button", nil, progressPage, "UIPanelButtonTemplate")
    reset:SetSize(110, 24)
    reset:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -18, 14)
    reset:SetText("Reset Default")
    reset:SetScript("OnClick", function()
        NSkin:ResetStatusBarTexture()
        frame:RebuildTextureList()
        NSkin:Print("progress bar texture reset to Naowh Gradient.")
    end)

    NSkin:SkinFlatButton(selected, selected:GetText(), CONTROL_BACKGROUND, DIVIDER_COLOR, 12)
    NSkin:SkinFlatButton(reset, "Reset Default", CONTROL_BACKGROUND, DIVIDER_COLOR, 12)
    if selected:GetFontString() then selected:GetFontString():SetAlpha(0) end
    if reset:GetFontString() then reset:GetFontString():SetAlpha(0) end

    local pages = {
        { key = "progress", label = "Progress Bars", page = progressPage },
    }

    for i = 1, #optionPageDefinitions do
        local definition = optionPageDefinitions[i]
        local page = definition.builder(frame)
        if page then
            page:Hide()
            pages[#pages + 1] = {
                key = definition.key,
                label = definition.label,
                page = page,
            }
        end
    end

    for i = 1, #pages do
        local pageInfo = pages[i]
        local tab = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        tab:SetSize(125, 26)
        tab:SetPoint("TOPLEFT", frame, "TOPLEFT", 16 + (i - 1) * 129, -34)
        tab:SetText("")
        NSkin:SkinFlatButton(tab, pageInfo.label, CONTROL_BACKGROUND, DIVIDER_COLOR, 12)
        tab:SetFrameLevel(frame:GetFrameLevel() + 5)
        tab:SetScript("OnClick", function()
            frame:SelectOptionsPage(pageInfo.key)
        end)
        pageInfo.tab = tab
    end

    function frame:SelectOptionsPage(key)
        self.selectedPageKey = key
        for i = 1, #pages do
            local pageInfo = pages[i]
            local selectedPage = pageInfo.key == key
            pageInfo.page:SetShown(selectedPage)
            pageInfo.tab:SetEnabled(not selectedPage)
            pageInfo.tab.NSkinFlatBackground:SetColorTexture(unpack(
                selectedPage and CONTROL_BACKGROUND_SELECTED or CONTROL_BACKGROUND
            ))
            if selectedPage and pageInfo.page.Refresh then
                pageInfo.page:Refresh()
            end
        end

        if key == "progress" then
            listBorder:Show()
            self:RebuildTextureList()
        end
    end

    frame:SetScript("OnShow", function(self)
        self:SelectOptionsPage(self.selectedPageKey or "progress")
    end)

    options = frame
    return frame
end

function NSkin:ToggleOptions()
    local frame = CreateOptionsWindow()
    if frame:IsShown() then
        frame:Hide()
    else
        frame:Show()
        frame:Raise()
    end
end
