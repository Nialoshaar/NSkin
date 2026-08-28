local _, NSkin = ...

local ROW_HEIGHT = 26
local builtInTextures = {
    { name = "Blizzard Flat", path = "Interface\\Buttons\\WHITE8X8", priority = 1 },
}

local function CollectTextures()
    local paths = {}
    local textures = {}
    local function Add(name, path, priority)
        if type(name) ~= "string" or type(path) ~= "string" or path == "" or paths[path] then return end
        paths[path] = true
        textures[#textures + 1] = { name = name, path = path, priority = priority or 100 }
    end
    for i = 1, #builtInTextures do
        local texture = builtInTextures[i]
        Add(texture.name, texture.path, texture.priority)
    end
    if _G.LibStub then
        local ok, media = pcall(function() return _G.LibStub("LibSharedMedia-3.0", true) end)
        local registered = ok and media and media:HashTable("statusbar")
        if registered then
            for name, path in pairs(registered) do Add(name, path) end
        end
    end
    table.sort(textures, function(left, right)
        if left.priority ~= right.priority then return left.priority < right.priority end
        return left.name:lower() < right.name:lower()
    end)
    return textures
end

local function FindName(textures, path)
    for i = 1, #textures do
        if textures[i].path == path then return textures[i].name end
    end
    return "Custom texture"
end

local function BuildProgressBarOptions(parent)
    local page = NSkin:CreateOptionsPage(parent)
    local title = page:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT")
    title:SetText("Progress Bars")
    NSkin:CreateOptionsSection(page, "Texture", 38)

    local selected = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
    selected:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -70)
    selected:SetPoint("RIGHT", page, "RIGHT", 0, 0)
    selected:SetHeight(28)
    local list = CreateFrame("Frame", nil, page, "BackdropTemplate")
    list:SetPoint("TOPLEFT", selected, "BOTTOMLEFT", 0, -6)
    list:SetPoint("RIGHT", page, "RIGHT", 0, 0)
    list:SetHeight(1)
    list:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    local reset = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
    reset:SetSize(110, 24)
    page.rows = {}

    function page:ApplyTheme()
        NSkin:SkinFlatButton(selected, selected:GetText() or "", nil, nil, 12)
        NSkin:SkinFlatButton(reset, "Reset Default", nil, nil, 12)
        local windowStyle = NSkin:GetStyle("window")
        list:SetBackdropColor(unpack(windowStyle.background))
        list:SetBackdropBorderColor(unpack(NSkin:GetBorderAccentColor()))
        local style = NSkin:GetStyle("options")
        local text = NSkin:GetStyle("button").text
        for i = 1, #self.rows do
            self.rows[i].highlight:SetColorTexture(unpack(style.listHighlight))
            self.rows[i].name:SetTextColor(unpack(text))
        end
    end

    function page:Rebuild()
        for i = 1, #self.rows do self.rows[i]:Hide() end
        self.textures = CollectTextures()
        local listHeight = math.max(1, #self.textures * ROW_HEIGHT + 8)
        list:SetHeight(listHeight)
        local active = NSkin:GetStatusBarTexture()
        local style = NSkin:GetStyle("options")
        for i = 1, #self.textures do
            local texture = self.textures[i]
            local row = self.rows[i]
            if not row then
                row = CreateFrame("Button", nil, list)
                row:SetHeight(ROW_HEIGHT)
                row.background = row:CreateTexture(nil, "BACKGROUND")
                row.background:SetAllPoints()
                row.highlight = row:CreateTexture(nil, "HIGHLIGHT")
                row.highlight:SetAllPoints()
                row.preview = row:CreateTexture(nil, "ARTWORK")
                row.preview:SetPoint("LEFT", 6, 0)
                row.preview:SetSize(145, 16)
                row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
                row.name:SetPoint("LEFT", row.preview, "RIGHT", 12, 0)
                row.name:SetPoint("RIGHT", -8, 0)
                row.name:SetJustifyH("LEFT")
                row:SetScript("OnClick", function(self)
                    NSkin:SetStatusBarTexture(self.texturePath)
                    page:Rebuild()
                    NSkin:Print("progress bar texture set to " .. self.textureName .. ".")
                end)
                self.rows[i] = row
            end
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", list, "TOPLEFT", 4, -4 - (i - 1) * ROW_HEIGHT)
            row:SetPoint("RIGHT", list, "RIGHT", -4, 0)
            row.preview:SetTexture(texture.path)
            row.name:SetText(texture.name)
            row.textureName = texture.name
            row.texturePath = texture.path
            row.background:SetColorTexture(unpack(
                texture.path == active and style.selectedListBackground or style.listBackground
            ))
            row:Show()
        end
        local name = FindName(self.textures, active)
        selected:SetText(name)
        NSkin:SetFlatButtonLabel(selected, name, 12)
        reset:ClearAllPoints()
        reset:SetPoint("TOPRIGHT", list, "BOTTOMRIGHT", 0, -14)
        self:SetContentHeight(122 + listHeight + 50)
        self:ApplyTheme()
    end

    selected:SetScript("OnClick", function()
        if list:IsShown() then
            list:Hide()
            reset:ClearAllPoints()
            reset:SetPoint("TOPRIGHT", selected, "BOTTOMRIGHT", 0, -14)
            page:SetContentHeight(160)
        else
            page:Rebuild()
            list:Show()
        end
    end)
    reset:SetScript("OnClick", function()
        NSkin:ResetStatusBarTexture()
        page:Rebuild()
        NSkin:Print("progress bar texture reset to "
            .. FindName(page.textures, NSkin:GetStyle("progressBar").texture) .. ".")
    end)
    function page:Refresh()
        self:Rebuild()
        list:Show()
    end
    if selected:GetFontString() then selected:GetFontString():SetAlpha(0) end
    if reset:GetFontString() then reset:GetFontString():SetAlpha(0) end
    page:SetContentHeight(160)
    return page
end

NSkin:RegisterOptionsPage({
    module = "BlizzardProgressBars",
    builder = BuildProgressBarOptions,
})
