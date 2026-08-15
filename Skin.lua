local _, NSkin = ...

-- Creates four simple texture edges without using BackdropTemplate or NineSlice.
-- The regions are owned by the target frame and do not alter protected state.
function NSkin:CreatePixelBorder(frame, key, size, color, outside)
    if not frame or not frame.CreateTexture then return nil end
    if key and frame[key] then return frame[key] end

    size = size or 1
    color = color or self.colors.border

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
        top:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", -size, 0)
        top:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", size, 0)
        bottom:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", -size, 0)
        bottom:SetPoint("TOPRIGHT", frame, "BOTTOMRIGHT", size, 0)
        left:SetPoint("TOPRIGHT", frame, "TOPLEFT", 0, size)
        left:SetPoint("BOTTOMRIGHT", frame, "BOTTOMLEFT", 0, -size)
        right:SetPoint("TOPLEFT", frame, "TOPRIGHT", 0, size)
        right:SetPoint("BOTTOMLEFT", frame, "BOTTOMRIGHT", 0, -size)
    else
        top:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
        top:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
        bottom:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
        bottom:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
        left:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
        left:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
        right:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
        right:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    end

    top:SetHeight(size)
    bottom:SetHeight(size)
    left:SetWidth(size)
    right:SetWidth(size)

    local border = { top = top, bottom = bottom, left = left, right = right }
    if key then frame[key] = border end
    return border
end
