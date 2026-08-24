local _, NSkin = ...

local ToyBoxSkin = NSkin:NewModule("ToyBox")

local TOYS_PER_PAGE = 18
local BORDER_SIZE = 1
local QUALITY_BORDER_KEY = "__NSkinCollectionQualityBorder"
local HEIRLOOM_QUALITY = _G.Enum and _G.Enum.ItemQuality and _G.Enum.ItemQuality.Heirloom or 7
local Item = _G.C_Item

local initialized = false

local function UpdateIconBorder(button, knownQuality)
    if not button or not button.iconTexture then return end

    local data = NSkin:GetSkinData(button)
    local itemID = button.itemID
    local border = data.qualityBorder

    if not itemID or itemID < 0 then
        NSkin:SetPixelBorderShown(border, false)
        return
    end

    if not border then
        border = NSkin:CreateQualityBorder(button, button.iconTexture, QUALITY_BORDER_KEY, BORDER_SIZE)
        if not border then return end
        data.qualityBorder = border
    end

    if data.qualityItemID ~= itemID then
        local quality = knownQuality or Item.GetItemQualityByID(itemID)
        if not NSkin:SetQualityBorder(border, quality) then return end

        data.qualityItemID = itemID
    else
        NSkin:SetPixelBorderShown(border, true)
    end
end

local function SkinCollectionButton(button, knownQuality)
    if not button then return end

    local data = NSkin:GetSkinData(button)
    if not data.collectionDecorationRemoved then
        local slotFrame = button.slotFrameCollected
        if slotFrame then
            if slotFrame.SetAtlas then slotFrame:SetAtlas(nil) end
            slotFrame:SetTexture(nil)
            slotFrame:Hide()
        end
        data.collectionDecorationRemoved = true
    end

    UpdateIconBorder(button, knownQuality)
end

function ToyBoxSkin:Initialize()
    if initialized then return end
    if not NSkin:IsModuleEnabled("ToyBox") then return end

    if not _G.hooksecurefunc then return end

    initialized = true

    local toyBox = _G.ToyBox
    local iconsFrame = toyBox and toyBox.iconsFrame
    if iconsFrame and type(_G.ToySpellButton_UpdateButton) == "function" then
        _G.hooksecurefunc("ToySpellButton_UpdateButton", SkinCollectionButton)

        for i = 1, TOYS_PER_PAGE do
            SkinCollectionButton(iconsFrame["spellButton" .. i])
        end
    end

    local heirloomsJournal = _G.HeirloomsJournal
    if heirloomsJournal and type(heirloomsJournal.UpdateButton) == "function" then
        _G.hooksecurefunc(heirloomsJournal, "UpdateButton", function(_, button)
            SkinCollectionButton(button, HEIRLOOM_QUALITY)
        end)
    end
end

NSkin:RegisterWindowSkin({
    module = "ToyBox",
    addon = "Blizzard_Collections",
    apply = function() ToyBoxSkin:Initialize() end,
})
