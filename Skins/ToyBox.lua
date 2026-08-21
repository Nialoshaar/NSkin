local _, NSkin = ...

local ToyBoxSkin = NSkin:NewModule("ToyBox")

local TOYS_PER_PAGE = 18
local BORDER_SIZE = 1
local QUALITY_BORDER_KEY = "__NSkinCollectionQualityBorder"
local QUALITY_ITEM_KEY = "__NSkinCollectionQualityItemID"
local HEIRLOOM_QUALITY = _G.Enum and _G.Enum.ItemQuality and _G.Enum.ItemQuality.Heirloom or 7
local Item = _G.C_Item

local initialized = false

local function UpdateIconBorder(button, knownQuality)
    if not button or not button.iconTexture then return end

    local itemID = button.itemID
    local border = button[QUALITY_BORDER_KEY]

    if not itemID or itemID < 0 then
        NSkin:SetPixelBorderShown(border, false)
        return
    end

    if not border then
        border = NSkin:CreateQualityBorder(button, button.iconTexture, QUALITY_BORDER_KEY, BORDER_SIZE)
        if not border then return end
    end

    if button[QUALITY_ITEM_KEY] ~= itemID then
        local quality = knownQuality or Item.GetItemQualityByID(itemID)
        if not NSkin:SetQualityBorder(border, quality) then return end

        button[QUALITY_ITEM_KEY] = itemID
    else
        NSkin:SetPixelBorderShown(border, true)
    end
end

local function SkinCollectionButton(button, knownQuality)
    if not button then return end

    if not button.__NSkinCollectionDecorationRemoved then
        local slotFrame = button.slotFrameCollected
        if slotFrame then
            if slotFrame.SetAtlas then slotFrame:SetAtlas(nil) end
            slotFrame:SetTexture(nil)
            slotFrame:Hide()
        end
        button.__NSkinCollectionDecorationRemoved = true
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

if NSkin:IsModuleEnabled("ToyBox") then
    if _G.C_AddOns and _G.C_AddOns.IsAddOnLoaded("Blizzard_Collections") then
        ToyBoxSkin:Initialize()
    elseif _G.EventUtil and _G.EventUtil.ContinueOnAddOnLoaded then
        _G.EventUtil.ContinueOnAddOnLoaded("Blizzard_Collections", function()
            ToyBoxSkin:Initialize()
        end)
    end
end
