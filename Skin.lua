local _, NSkin = ...

-- Creates four simple texture edges without using BackdropTemplate or NineSlice.
-- The regions are owned by the target frame and do not alter protected state.
function NSkin:CreatePixelBorder(frame, key, size, color, outside, anchor)
    if not frame or not frame.CreateTexture then return nil end
    if key and frame[key] then return frame[key] end

    size = size or 1
    color = color or self.colors.border
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
    if key then frame[key] = border end
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

function NSkin:CreateQualityBorder(frame, anchor, key, size, outside)
    local border = self:CreatePixelBorder(frame, key, size, nil, outside == true, anchor)
    self:SetPixelBorderShown(border, false)
    return border
end

function NSkin:SetQualityBorder(border, quality)
    local item = _G.C_Item
    if not border or quality == nil or not item or not item.GetItemQualityColor then
        self:SetPixelBorderShown(border, false)
        return false
    end

    local red, green, blue = item.GetItemQualityColor(quality)
    self:SetPixelBorderColor(border, red, green, blue)
    self:SetPixelBorderShown(border, true)
    return true
end
