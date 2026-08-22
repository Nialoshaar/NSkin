local _, NSkin = ...

local EncounterJournalSkin = NSkin:NewModule("EncounterJournal")

local BORDER_SIZE = 1
local CLEAR_TEXTURE = 0

-- EncounterInstanceButtonTemplate uses only this subregion of its source
-- texture. These values add a small zoom while remaining inside that region.
local CROP_LEFT = 0.035
local CROP_RIGHT = 0.648
local CROP_TOP = 0.045
local CROP_BOTTOM = 0.697

local initialized = false
local hookedScrollBox
local refreshPending = false
local refreshPasses = 0
local lastTabID
local bossScrollBox
local concealedScrollBox
local concealedOriginalAlpha

local cardFrameAtlases = {
    ["shop-card-wide-frame-default"] = true,
    ["shop-card-wide-frame-hover"] = true,
}

local function ClearButtonTextures(button)
    if not button then return end
    button:SetNormalTexture(CLEAR_TEXTURE)
    button:SetPushedTexture(CLEAR_TEXTURE)
    button:SetHighlightTexture(CLEAR_TEXTURE)
    if button.SetDisabledTexture then button:SetDisabledTexture(CLEAR_TEXTURE) end
end

local function IsTexture(region)
    return region and region.IsObjectType and region:IsObjectType("Texture")
end

local function IsFontString(region)
    return region and region.IsObjectType and region:IsObjectType("FontString")
end

local function RemoveMasks(texture)
    if not texture.GetNumMaskTextures
        or not texture.GetMaskTexture
        or not texture.RemoveMaskTexture
    then
        return
    end

    local masks = {}
    for i = 1, texture:GetNumMaskTextures() do
        masks[#masks + 1] = texture:GetMaskTexture(i)
    end
    for i = 1, #masks do
        if masks[i] then texture:RemoveMaskTexture(masks[i]) end
    end
end

local function ApplyButtonStateTextures(button)
    -- File ID 0 clears a Button state slot. Unlike nil or a runtime transparent
    -- region, it cannot be made visible again by the native button-state engine.
    button:SetNormalTexture(CLEAR_TEXTURE)
    button:SetPushedTexture(CLEAR_TEXTURE)
    button:SetHighlightTexture(CLEAR_TEXTURE)
    if button.SetDisabledTexture then button:SetDisabledTexture(CLEAR_TEXTURE) end
end

function EncounterJournalSkin:StyleBossButton(button)
    if not button or not button.creature or not button.text then return end

    ClearButtonTextures(button)

    local background = button.__NSkinBossBackground
    if not background then
        background = button:CreateTexture(nil, "BACKGROUND", nil, -7)
        background:SetAllPoints(button)
        button.__NSkinBossBackground = background
    end
    background:SetColorTexture(unpack(NSkin:GetStyle("encounterCard").background))
    background:Show()
end

function EncounterJournalSkin:StyleBossFrames(scrollBox)
    if not scrollBox or not scrollBox.ForEachFrame then return end
    scrollBox:ForEachFrame(function(button)
        EncounterJournalSkin:StyleBossButton(button)
    end)
end

function EncounterJournalSkin:StyleInstancePage()
    local journal = _G.EncounterJournal
    local encounter = journal and journal.encounter
    local instance = encounter and encounter.instance
    local info = encounter and encounter.info
    if not instance or not info then return end

    -- The lore image contains its ornamental frame in the source texture.
    -- Use the image-only portion and rotate it back into its original
    -- orientation, producing a clean rectangular dungeon image.
    local loreImage = instance.loreBG
    if IsTexture(loreImage) then
        loreImage:SetTexCoord(0.71, 0.06, 0.582, 0.08)
        if loreImage.SetRotation then loreImage:SetRotation(math.rad(180)) end

        local imageBorder = instance.__NSkinLoreImageBorder
        if not imageBorder then
            imageBorder = CreateFrame("Frame", nil, instance)
            imageBorder:SetPoint("TOPLEFT", loreImage, "TOPLEFT", -1, 1)
            imageBorder:SetPoint("BOTTOMRIGHT", loreImage, "BOTTOMRIGHT", 1, -1)
            imageBorder:SetFrameLevel(instance:GetFrameLevel() + 1)
            instance.__NSkinLoreImageBorder = imageBorder
        end
        local border = NSkin:CreatePixelBorder(
            imageBorder,
            "__NSkinBorder",
            BORDER_SIZE,
            NSkin:GetStyle("encounterCard").border,
            false
        )
        NSkin:SetPixelBorderColor(border, unpack(NSkin:GetStyle("encounterCard").border))
    end

    if instance.titleBG then
        instance.titleBG:SetAlpha(0)
        instance.titleBG:Hide()
    end

    local instanceButton = info.instanceButton
    if instanceButton and IsTexture(instanceButton.icon) then
        ClearButtonTextures(instanceButton)
        instanceButton.icon:SetSize(32, 32)
        -- This inherited icon keeps a Blizzard-owned mask that cannot be
        -- reliably detached. SetTexCoord is illegal while that mask exists,
        -- so preserve its native coordinates instead of generating errors.
    end

    self:StyleBossFrames(info.BossesScrollBox)
end

local function StripCardFrameAtlases(button)
    if not button.GetRegions then return end

    local regions = { button:GetRegions() }
    for i = 1, #regions do
        local region = regions[i]
        if IsTexture(region) then
            local atlas = region.GetAtlas and region:GetAtlas() or nil
            if region.__NSkinEncounterCardFrame or cardFrameAtlases[atlas] then
                region.__NSkinEncounterCardFrame = true
                if region.SetAtlas then region:SetAtlas(nil) end
                region:SetTexture(nil)
                region:SetAlpha(0)
                region:Hide()
            end
        end
    end
end

local function GetOrCreateHover(button)
    local hover = button.__NSkinEncounterHover
    if hover then
        hover:SetColorTexture(unpack(NSkin:GetStyle("encounterCard").hover))
        return hover
    end

    hover = button:CreateTexture(nil, "ARTWORK", nil, 7)
    hover:SetPoint("TOPLEFT", button, "TOPLEFT", BORDER_SIZE, -BORDER_SIZE)
    hover:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -BORDER_SIZE, BORDER_SIZE)
    hover:SetColorTexture(unpack(NSkin:GetStyle("encounterCard").hover))
    hover:SetBlendMode("ADD")
    hover:Hide()
    button.__NSkinEncounterHover = hover

    button:HookScript("OnEnter", function(self)
        local overlay = self.__NSkinEncounterHover
        if overlay then overlay:Show() end
    end)
    button:HookScript("OnLeave", function(self)
        local overlay = self.__NSkinEncounterHover
        if overlay then overlay:Hide() end
    end)

    return hover
end

function EncounterJournalSkin:StyleButton(button)
    local background = button and button.bgImage
    if not button
        or not IsTexture(background)
        or not IsFontString(button.name)
    then
        return
    end

    RemoveMasks(background)

    background:ClearAllPoints()
    background:SetPoint("TOPLEFT", button, "TOPLEFT", BORDER_SIZE, -BORDER_SIZE)
    background:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -BORDER_SIZE, BORDER_SIZE)
    background:SetTexCoord(CROP_LEFT, CROP_RIGHT, CROP_TOP, CROP_BOTTOM)
    background:SetAlpha(1)
    background:Show()

    local border = NSkin:CreatePixelBorder(
        button,
        "__NSkinEncounterBorder",
        BORDER_SIZE,
        NSkin:GetStyle("encounterCard").border,
        false
    )
    NSkin:SetPixelBorderColor(border, unpack(NSkin:GetStyle("encounterCard").border))

    ApplyButtonStateTextures(button)
    StripCardFrameAtlases(button)
    local hover = GetOrCreateHover(button)
    if button.IsMouseOver then hover:SetShown(button:IsMouseOver()) end
    button.name:SetDrawLayer("OVERLAY", 6)
end

function EncounterJournalSkin:OnInitializedFrame(button)
    self:StyleButton(button)
    self:QueueRefresh()
end

function EncounterJournalSkin:StyleVisibleFrames(scrollBox)
    if not scrollBox or not scrollBox.ForEachFrame then return end
    scrollBox:ForEachFrame(function(button)
        EncounterJournalSkin:StyleButton(button)
    end)
end

function EncounterJournalSkin:RefreshTheme()
    if not initialized then return end
    self:StyleVisibleFrames(hookedScrollBox)
    self:StyleBossFrames(bossScrollBox)
    self:StyleInstancePage()
end

local function FinishConcealment(scrollBox)
    if not concealedScrollBox or (scrollBox and scrollBox ~= concealedScrollBox) then
        return
    end

    concealedScrollBox:SetAlpha(concealedOriginalAlpha or 1)
    concealedScrollBox = nil
    concealedOriginalAlpha = nil
end

function EncounterJournalSkin:ConcealUntilStyled(scrollBox)
    if not scrollBox or not scrollBox.SetAlpha then return end

    if concealedScrollBox and concealedScrollBox ~= scrollBox then
        FinishConcealment()
    end

    if not concealedScrollBox then
        concealedScrollBox = scrollBox
        concealedOriginalAlpha = scrollBox:GetAlpha()
    end

    scrollBox:SetAlpha(0)
end

function EncounterJournalSkin:QueueRefresh()
    if refreshPending then return end
    refreshPending = true

    C_Timer.After(0, function()
        refreshPending = false
        if hookedScrollBox then
            refreshPasses = refreshPasses + 1
            EncounterJournalSkin:StyleVisibleFrames(hookedScrollBox)
            FinishConcealment(hookedScrollBox)
        end
    end)
end

function EncounterJournalSkin:OnTabSet(journal, tabID)
    lastTabID = tabID

    local dungeonTabID = journal and journal.dungeonsTab and journal.dungeonsTab:GetID()
    local raidTabID = journal and journal.raidsTab and journal.raidsTab:GetID()
    if tabID ~= dungeonTabID and tabID ~= raidTabID then return end

    self:Initialize()
    if hookedScrollBox then
        self:ConcealUntilStyled(hookedScrollBox)
        self:StyleVisibleFrames(hookedScrollBox)
    end
    self:QueueRefresh()
end

function EncounterJournalSkin:Initialize()
    if initialized then return end
    if not NSkin:IsModuleEnabled("EncounterJournal") then return end

    local journal = _G.EncounterJournal
    local instanceSelect = journal and journal.instanceSelect
    local scrollBox = instanceSelect and instanceSelect.ScrollBox
    local scrollEvents = _G.ScrollBoxListMixin and _G.ScrollBoxListMixin.Event

    if not scrollBox
        or not scrollBox.ForEachFrame
        or type(scrollBox.Update) ~= "function"
        or not hooksecurefunc
    then
        NSkin:Print("Encounter Journal skin could not attach to the Midnight ScrollBox update lifecycle.")
        return
    end

    initialized = true
    hookedScrollBox = scrollBox
    local info = journal.encounter and journal.encounter.info
    bossScrollBox = info and info.BossesScrollBox
    hooksecurefunc(scrollBox, "Update", function(updatedScrollBox)
        EncounterJournalSkin:StyleVisibleFrames(updatedScrollBox)
        FinishConcealment(updatedScrollBox)
        EncounterJournalSkin:QueueRefresh()
    end)

    if scrollBox.RegisterCallback
        and scrollEvents
        and scrollEvents.OnInitializedFrame
    then
        scrollBox:RegisterCallback(
            scrollEvents.OnInitializedFrame,
            self.OnInitializedFrame,
            self
        )
    end

    -- Style frames already present when the load-on-demand addon finishes.
    self:StyleVisibleFrames(scrollBox)
    self:QueueRefresh()

    if journal.HookScript then
        journal:HookScript("OnShow", function()
            EncounterJournalSkin:ConcealUntilStyled(scrollBox)
            EncounterJournalSkin:QueueRefresh()
        end)
        journal:HookScript("OnHide", function()
            FinishConcealment(scrollBox)
        end)
    end
    if instanceSelect.HookScript then
        instanceSelect:HookScript("OnShow", function()
            EncounterJournalSkin:ConcealUntilStyled(scrollBox)
            EncounterJournalSkin:QueueRefresh()
        end)
    end
    if type(_G.EncounterJournal_ListInstances) == "function" then
        hooksecurefunc("EncounterJournal_ListInstances", function()
            EncounterJournalSkin:ConcealUntilStyled(scrollBox)
            EncounterJournalSkin:QueueRefresh()
        end)
    end


    if bossScrollBox and bossScrollBox.ForEachFrame and type(bossScrollBox.Update) == "function" then
        hooksecurefunc(bossScrollBox, "Update", function(updatedScrollBox)
            EncounterJournalSkin:StyleBossFrames(updatedScrollBox)
        end)

        if bossScrollBox.RegisterCallback
            and scrollEvents
            and scrollEvents.OnInitializedFrame
        then
            bossScrollBox:RegisterCallback(
                scrollEvents.OnInitializedFrame,
                self.StyleBossButton,
                self
            )
        end
    end

    if type(_G.EncounterJournal_DisplayInstance) == "function" then
        hooksecurefunc("EncounterJournal_DisplayInstance", function()
            EncounterJournalSkin:StyleInstancePage()
        end)
    end

    self:StyleInstancePage()
end

local function DescribeTexture(texture)
    if not texture then return "nil" end

    local name = texture.GetName and texture:GetName() or "<unnamed>"
    local shown = texture.IsShown and texture:IsShown() and "shown" or "hidden"
    local alpha = texture.GetAlpha and texture:GetAlpha() or "?"
    local path = texture.GetTexture and texture:GetTexture() or nil
    local atlas = texture.GetAtlas and texture:GetAtlas() or nil
    local layer, sublevel
    if texture.GetDrawLayer then layer, sublevel = texture:GetDrawLayer() end

    return ("%s %s alpha=%s texture=%s atlas=%s layer=%s:%s"):format(
        name,
        shown,
        tostring(alpha),
        tostring(path),
        tostring(atlas),
        tostring(layer),
        tostring(sublevel)
    )
end

function EncounterJournalSkin:Debug()
    NSkin:Print(("journal initialized=%s hookedScrollBox=%s lastTabID=%s refreshPending=%s refreshPasses=%d concealed=%s"):format(
        tostring(initialized),
        tostring(hookedScrollBox),
        tostring(lastTabID),
        tostring(refreshPending),
        refreshPasses,
        tostring(concealedScrollBox ~= nil)
    ))

    local journal = _G.EncounterJournal
    local instanceSelect = journal and journal.instanceSelect
    local scrollBox = instanceSelect and instanceSelect.ScrollBox
    if not scrollBox then
        NSkin:Print("journal debug: EncounterJournal.instanceSelect.ScrollBox is unavailable.")
        return
    end
    if not scrollBox.GetFrames then
        NSkin:Print("journal debug: ScrollBox:GetFrames is unavailable.")
        return
    end

    local frames = scrollBox:GetFrames()
    NSkin:Print(("journal shown=%s instanceSelectShown=%s frames=%d"):format(
        tostring(journal:IsShown()),
        tostring(instanceSelect:IsShown()),
        #frames
    ))

    for i = 1, #frames do
        local button = frames[i]
        local label = button.name and button.name:GetText() or "<no label>"

        print(("|cff33aaffNSkin journal card %d:|r %s styledBorder=%s hoverShown=%s"):format(
            i,
            tostring(label),
            tostring(button.__NSkinEncounterBorder ~= nil),
            tostring(button.__NSkinEncounterHover and button.__NSkinEncounterHover:IsShown())
        ))
        print("  normal:", DescribeTexture(button:GetNormalTexture()))
        print("  pushed:", DescribeTexture(button:GetPushedTexture()))
        print("  highlight:", DescribeTexture(button:GetHighlightTexture()))
        if button.GetDisabledTexture then
            print("  disabled:", DescribeTexture(button:GetDisabledTexture()))
        end

        if i <= 2 and button.GetRegions then
            local regions = { button:GetRegions() }
            print(("  direct regions (%d):"):format(#regions))
            for regionIndex = 1, #regions do
                local region = regions[regionIndex]
                if region and region.IsObjectType and region:IsObjectType("Texture") then
                    print(("    [%d] %s"):format(regionIndex, DescribeTexture(region)))
                elseif region and region.IsObjectType and region:IsObjectType("FontString") then
                    local name = region.GetName and region:GetName() or "<unnamed>"
                    print(("    [%d] FontString %s text=%s"):format(
                        regionIndex,
                        tostring(name),
                        tostring(region:GetText())
                    ))
                end
            end
        end
    end
end

local function ContinueAfterJournalLoads()
    if _G.EventUtil and _G.EventUtil.ContinueOnAddOnLoaded then
        _G.EventUtil.ContinueOnAddOnLoaded("Blizzard_EncounterJournal", function()
            EncounterJournalSkin:Initialize()
        end)
    else
        NSkin:RegisterEvent("ADDON_LOADED", function(_, addonName)
            if addonName == "Blizzard_EncounterJournal" then
                EncounterJournalSkin:Initialize()
            end
        end)
    end
end

NSkin:RegisterModuleInitializer("EncounterJournal", function()
    if _G.EventRegistry and _G.EventRegistry.RegisterCallback then
        _G.EventRegistry:RegisterCallback(
            "EncounterJournal.TabSet",
            EncounterJournalSkin.OnTabSet,
            EncounterJournalSkin
        )
    end

    ContinueAfterJournalLoads()
end)
