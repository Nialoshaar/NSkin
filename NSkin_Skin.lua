local _, NSkin = ...

local skinData = setmetatable({}, { __mode = "k" })

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
        return edge
    end

    local top = NewEdge()
    local bottom = NewEdge()
    local left = NewEdge()
    local right = NewEdge()

    if outside then
        top:SetPoint("BOTTOMLEFT", anchor, "TOPLEFT", -size, 0)
        top:SetPoint("BOTTOMRIGHT", anchor, "TOPRIGHT", size, 0)
        bottom:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", -size, 0)
        bottom:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", size, 0)
        left:SetPoint("TOPRIGHT", anchor, "TOPLEFT", 0, size)
        left:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMLEFT", 0, -size)
        right:SetPoint("TOPLEFT", anchor, "TOPRIGHT", 0, size)
        right:SetPoint("BOTTOMLEFT", anchor, "BOTTOMRIGHT", 0, -size)
    else
        top:SetPoint("TOPLEFT", anchor, "TOPLEFT", 0, 0)
        top:SetPoint("TOPRIGHT", anchor, "TOPRIGHT", 0, 0)
        bottom:SetPoint("BOTTOMLEFT", anchor, "BOTTOMLEFT", 0, 0)
        bottom:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", 0, 0)
        left:SetPoint("TOPLEFT", anchor, "TOPLEFT", 0, 0)
        left:SetPoint("BOTTOMLEFT", anchor, "BOTTOMLEFT", 0, 0)
        right:SetPoint("TOPRIGHT", anchor, "TOPRIGHT", 0, 0)
        right:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", 0, 0)
    end

    top:SetHeight(size)
    bottom:SetHeight(size)
    left:SetWidth(size)
    right:SetWidth(size)

    local border = { top = top, bottom = bottom, left = left, right = right }
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
end

function NSkin:SetPixelBorderSize(border, size)
    if not border or not size then return end
    border.top:SetHeight(size)
    border.bottom:SetHeight(size)
    border.left:SetWidth(size)
    border.right:SetWidth(size)
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
    background:Show()
    local border = self:CreatePixelBorder(frame, key .. "Border", 1, borderColor)
    self:SetPixelBorderColor(border, unpack(borderColor))
    return background
end
