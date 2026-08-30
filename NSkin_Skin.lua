local _, NSkin = ...

local skinData = setmetatable({}, { __mode = "k" })
local pixelBorders = setmetatable({}, { __mode = "k" })
local QueuePixelBorderResnap

function NSkin:GetPhysicalPixelSize(frame)
    local _, physicalHeight
    if _G.GetPhysicalScreenSize then
        _, physicalHeight = _G.GetPhysicalScreenSize()
    end
    physicalHeight = tonumber(physicalHeight) or 768
    local scale = frame and frame.GetEffectiveScale and frame:GetEffectiveScale()
        or (UIParent and UIParent:GetEffectiveScale()) or 1
    if not scale or scale <= 0 then scale = 1 end
    return (768 / math.max(1, physicalHeight)) / scale
end

function NSkin:SnapToPhysicalPixel(frame, value)
    value = tonumber(value) or 0
    local pixel = self:GetPhysicalPixelSize(frame)
    local scaled = value / pixel
    if scaled >= 0 then return math.floor(scaled + 0.5) * pixel end
    return math.ceil(scaled - 0.5) * pixel
end

function NSkin:ConfigureOwnedPixelTexture(texture)
    if not texture then return end
    if texture.SetSnapToPixelGrid then texture:SetSnapToPixelGrid(false) end
    if texture.SetTexelSnappingBias then texture:SetTexelSnappingBias(0) end
end

local function ApplyPixelBorderGeometry(border)
    if not border or not border.anchor then return end
    local anchor = border.anchor
    local pixel = NSkin:GetPhysicalPixelSize(anchor)
    local requestedSize = math.max(1, tonumber(border.requestedSize) or 1)
    local thickness = requestedSize * pixel
    local requestedPadding = tonumber(border.requestedPadding)
    local padding = requestedPadding and requestedPadding * pixel or 0
    border.pixelSize = pixel
    border.effectiveSize = thickness
    border.effectivePadding = padding

    for _, edge in ipairs({ border.top, border.bottom, border.left, border.right }) do
        edge:ClearAllPoints()
        NSkin:ConfigureOwnedPixelTexture(edge)
    end
    if border.outside and requestedPadding == nil then
        border.top:SetPoint("BOTTOMLEFT", anchor, "TOPLEFT", -thickness, 0)
        border.top:SetPoint("BOTTOMRIGHT", anchor, "TOPRIGHT", thickness, 0)
        border.bottom:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", -thickness, 0)
        border.bottom:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", thickness, 0)
        border.left:SetPoint("TOPRIGHT", anchor, "TOPLEFT", 0, thickness)
        border.left:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMLEFT", 0, -thickness)
        border.right:SetPoint("TOPLEFT", anchor, "TOPRIGHT", 0, thickness)
        border.right:SetPoint("BOTTOMLEFT", anchor, "BOTTOMRIGHT", 0, -thickness)
    else
        border.top:SetPoint("TOPLEFT", anchor, "TOPLEFT", -padding, padding)
        border.top:SetPoint("TOPRIGHT", anchor, "TOPRIGHT", padding, padding)
        border.bottom:SetPoint("BOTTOMLEFT", anchor, "BOTTOMLEFT", -padding, -padding)
        border.bottom:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", padding, -padding)
        border.left:SetPoint("TOPLEFT", anchor, "TOPLEFT", -padding, padding)
        border.left:SetPoint("BOTTOMLEFT", anchor, "BOTTOMLEFT", -padding, -padding)
        border.right:SetPoint("TOPRIGHT", anchor, "TOPRIGHT", padding, padding)
        border.right:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", padding, -padding)
    end
    border.top:SetHeight(thickness)
    border.bottom:SetHeight(thickness)
    border.left:SetWidth(thickness)
    border.right:SetWidth(thickness)
end

function NSkin:ResnapPixelBorder(border)
    ApplyPixelBorderGeometry(border)
end

function NSkin:ResnapAllPixelBorders()
    for border in pairs(pixelBorders) do ApplyPixelBorderGeometry(border) end
end

local function QueueBorderSetResnap(data)
    if not data or data.pending then return end
    data.pending = true
    local function Resnap()
        data.pending = nil
        for border in pairs(data.borders or {}) do ApplyPixelBorderGeometry(border) end
    end
    if C_Timer and C_Timer.After then C_Timer.After(0, Resnap) else Resnap() end
end

function NSkin:GetSkinData(object, namespace, create)
    if not object then return nil end

    -- Preserve GetSkinData(object, false) while allowing each subsystem to
    -- keep its state in a clearly named table.
    if type(namespace) == "boolean" then
        create = namespace
        namespace = nil
    end

    local data = skinData[object]
    if not data and create ~= false then
        data = {}
        skinData[object] = data
    end
    if not data or not namespace then return data end

    local scoped = data[namespace]
    if not scoped and create ~= false then
        scoped = {}
        data[namespace] = scoped
    end
    return scoped
end

function NSkin:GetPixelBorder(frame, key)
    local data = self:GetSkinData(frame, "primitives", false)
    return data and data.borders and data.borders[key]
end

function NSkin:GetFlatBackground(frame, key)
    local data = self:GetSkinData(frame, "primitives", false)
    return data and data.backgrounds and data.backgrounds[key or "NSkinFlatBackground"]
end

-- Creates four simple texture edges without using BackdropTemplate or NineSlice.
-- The regions are owned by the target frame and do not alter protected state.

-- Icons Skinning
function NSkin:CreatePixelBorder(frame, key, size, color, outside, anchor)
    if not frame or not frame.CreateTexture then return nil end
    local data = self:GetSkinData(frame, "primitives")
    if key then
        data.borders = data.borders or {}
        if data.borders[key] then return data.borders[key] end
    end

    size = size or 1
    color = color or self:GetStyle("icon").border
    anchor = anchor or frame

    local function NewEdge()
        local edge = frame:CreateTexture(nil, "OVERLAY", nil, 7)
        edge:SetColorTexture(unpack(color))
        self:ConfigureOwnedPixelTexture(edge)
        return edge
    end

    local top = NewEdge()
    local bottom = NewEdge()
    local left = NewEdge()
    local right = NewEdge()

    local border = { top = top, bottom = bottom, left = left, right = right,
        frame = frame, anchor = anchor, outside = outside == true,
        requestedSize = tonumber(size) or 1 }
    pixelBorders[border] = true
    ApplyPixelBorderGeometry(border)
    local anchorData = self:GetSkinData(anchor, "physicalPixels")
    anchorData.borders = anchorData.borders
        or setmetatable({}, { __mode = "k" })
    anchorData.borders[border] = true
    if anchorData and not anchorData.resnapHooked then
        anchorData.resnapHooked = true
        if anchor.HookScript then
            anchor:HookScript("OnSizeChanged", function()
                QueueBorderSetResnap(anchorData)
            end)
            anchor:HookScript("OnShow", function()
                QueueBorderSetResnap(anchorData)
            end)
        end
        if _G.hooksecurefunc and anchor.SetScale then
            pcall(_G.hooksecurefunc, anchor, "SetScale", function()
                QueueBorderSetResnap(anchorData)
            end)
        end
    end
    if key then data.borders[key] = border end
    return border
end

function NSkin:SetPixelBorderShown(border, shown)
    if not border or border.shown == shown then return end

    border.top:SetShown(shown)
    border.bottom:SetShown(shown)
    border.left:SetShown(shown)
    border.right:SetShown(shown)
    border.shown = shown
end

function NSkin:SetPixelBorderColor(border, red, green, blue, alpha)
    if not border then return end

    alpha = alpha or 1
    border.top:SetColorTexture(red, green, blue, alpha)
    border.bottom:SetColorTexture(red, green, blue, alpha)
    border.left:SetColorTexture(red, green, blue, alpha)
    border.right:SetColorTexture(red, green, blue, alpha)
    self:ConfigureOwnedPixelTexture(border.top)
    self:ConfigureOwnedPixelTexture(border.bottom)
    self:ConfigureOwnedPixelTexture(border.left)
    self:ConfigureOwnedPixelTexture(border.right)
end

function NSkin:SetPixelBorderSize(border, size)
    if not border or not size then return end
    border.requestedSize = tonumber(size) or border.requestedSize or 1
    ApplyPixelBorderGeometry(border)
end

function NSkin:SetPixelBorderPadding(border, padding)
    if not border or not border.anchor then return end
    border.requestedPadding = tonumber(padding) or 0
    border.padding = border.requestedPadding
    ApplyPixelBorderGeometry(border)
end

function NSkin:CreateQualityBorder(frame, anchor, key, size, outside)
    local border = self:CreatePixelBorder(frame, key, size, nil, outside == true, anchor)
    self:SetPixelBorderShown(border, false)
    return border
end

function NSkin:SetQualityBorder(border, quality)
    local item = _G.C_Item
    if not border then return false end
    local style = self:GetStyle("icon")
    if style and style.qualityColor == false then
        self:SetPixelBorderColor(border, unpack(style.border))
        self:SetPixelBorderShown(border, true)
        return true
    end
    if quality == nil or not item or not item.GetItemQualityColor then
        self:SetPixelBorderShown(border, false)
        return false
    end

    local red, green, blue = item.GetItemQualityColor(quality)
    self:SetPixelBorderColor(border, red, green, blue)
    self:SetPixelBorderShown(border, true)
    return true
end

function NSkin:HideTextureRegions(frame, textureToKeep)
    if not frame or not frame.GetRegions then return end

    local regions = { frame:GetRegions() }
    for i = 1, #regions do
        local region = regions[i]
        if region ~= textureToKeep and region.GetObjectType
            and region:GetObjectType() == "Texture" then
            -- Blizzard frequently shows these regions again when control
            -- state changes. Alpha remains suppressed across those Show calls.
            region:SetAlpha(0)
            region:SetTexture(nil)
            region:Hide()
        end
    end
end

function NSkin:CreateFlatBackground(frame, key, color, borderColor)
    if not frame or not frame.CreateTexture or not color or not borderColor then return nil end

    key = key or "NSkinFlatBackground"
    local data = self:GetSkinData(frame, "primitives")
    data.backgrounds = data.backgrounds or {}
    local background = data.backgrounds[key]
    if not background then
        background = frame:CreateTexture(nil, "BACKGROUND", nil, 7)
        background:SetPoint("TOPLEFT", 1, -1)
        background:SetPoint("BOTTOMRIGHT", -1, 1)
        data.backgrounds[key] = background
    end
    background:SetColorTexture(unpack(color))
    self:ConfigureOwnedPixelTexture(background)
    background:Show()
    local border = self:CreatePixelBorder(frame, key .. "Border", 1, borderColor)
    self:SetPixelBorderColor(border, unpack(borderColor))
    return background
end

local pixelResnapPending = false
QueuePixelBorderResnap = function()
    if pixelResnapPending then return end
    pixelResnapPending = true
    local function Resnap()
        pixelResnapPending = false
        NSkin:ResnapAllPixelBorders()
    end
    if C_Timer and C_Timer.After then C_Timer.After(0, Resnap) else Resnap() end
end

NSkin:RegisterEvent("UI_SCALE_CHANGED", QueuePixelBorderResnap)
NSkin:RegisterEvent("DISPLAY_SIZE_CHANGED", QueuePixelBorderResnap)
