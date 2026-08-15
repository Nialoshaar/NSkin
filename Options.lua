local _, NSkin = ...

local WINDOW_WIDTH = 560
local WINDOW_HEIGHT = 360
local ROW_HEIGHT = 26

local options

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

    frame.TitleText:SetText("Nialo Skin — Progress Bar Texture")

    local label = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    label:SetPoint("TOPLEFT", 18, -42)
    label:SetText("Texture")

    local selected = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    selected:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -8)
    selected:SetPoint("RIGHT", frame, "RIGHT", -18, 0)
    selected:SetHeight(28)
    selected:SetText("Naowh Gradient")
    frame.selectedButton = selected

    local listBorder = CreateFrame("Frame", nil, frame, "BackdropTemplate")
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

        selected:SetText(FindTextureName(self.textures, NSkin:GetStatusBarTexture()))
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

    local reset = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    reset:SetSize(110, 24)
    reset:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -18, 14)
    reset:SetText("Reset Default")
    reset:SetScript("OnClick", function()
        NSkin:ResetStatusBarTexture()
        frame:RebuildTextureList()
        NSkin:Print("progress bar texture reset to Naowh Gradient.")
    end)

    frame:SetScript("OnShow", function(self)
        listBorder:Show()
        self:RebuildTextureList()
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
