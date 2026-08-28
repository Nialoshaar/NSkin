local _, NSkin = ...

local ProgressBars = NSkin:NewModule("BlizzardProgressBars")

local BORDER_SIZE = 1
local PROGRESS_BORDER_KEY = "__NSkinProgressBorder"
local PROGRESS_STATE = "progressBars"
local SCENARIO_TIMER_BAR_Y = 0
local FALLBACK_STATUS_BAR = "Interface\\Buttons\\WHITE8X8"

function NSkin:GetStatusBarTexture()
    local texture = self:GetStyle("progressBar").texture
    return type(texture) == "string" and texture ~= "" and texture or FALLBACK_STATUS_BAR
end

function NSkin:SetStatusBarTexture(texture)
    if type(texture) ~= "string" then return false end
    texture = texture:match("^%s*(.-)%s*$")
    if texture == "" then return false end
    return self:SetThemeOverride("progressBar.texture", texture)
end

function NSkin:ResetStatusBarTexture()
    return self:ResetThemeOverride("progressBar.texture")
end

local styledBars = setmetatable({}, { __mode = "k" })
local protectedRegions = setmetatable({}, { __mode = "k" })
local strippedRegions = setmetatable({}, { __mode = "k" })
local hiddenFrames = setmetatable({}, { __mode = "k" })

local statusHookInstalled = false
local scenarioHookInstalled = false
local tooltipHooksInstalled = false
local scanPending = false
local conflictWarningShown = false
local hookedObjectiveTrackers = setmetatable({}, { __mode = "k" })

local function IsStatusBar(object)
    return object
        and object.GetObjectType
        and object:GetObjectType() == "StatusBar"
        and object.SetStatusBarTexture
end

local function HideTexture(texture)
    if not texture
        or not texture.IsObjectType
        or not texture:IsObjectType("Texture")
        or protectedRegions[texture]
    then
        return
    end

    local function EnforceHidden(self)
        local data = NSkin:GetSkinData(self, PROGRESS_STATE)
        if data.hiding then return end
        data.hiding = true

        if self.SetAlpha then self:SetAlpha(0) end
        if self.SetTexture then self:SetTexture(nil) end
        self:Hide()

        data.hiding = false
    end

    if strippedRegions[texture] then
        EnforceHidden(texture)
        return
    end

    strippedRegions[texture] = true
    if texture.SetAtlas then pcall(texture.SetAtlas, texture, nil) end
    EnforceHidden(texture)

    if hooksecurefunc then
        pcall(hooksecurefunc, texture, "Show", function(self)
            if not protectedRegions[self] then EnforceHidden(self) end
        end)
        if texture.SetShown then
            pcall(hooksecurefunc, texture, "SetShown", function(self, shown)
                if shown and not protectedRegions[self] then EnforceHidden(self) end
            end)
        end
        if texture.SetAtlas then
            pcall(hooksecurefunc, texture, "SetAtlas", function(self, atlas)
                if atlas and not protectedRegions[self] then EnforceHidden(self) end
            end)
        end
        pcall(hooksecurefunc, texture, "SetTexture", function(self, path)
            if path and not protectedRegions[self] then EnforceHidden(self) end
        end)
        if texture.SetAlpha then
            pcall(hooksecurefunc, texture, "SetAlpha", function(self, alpha)
                if alpha ~= 0 and not protectedRegions[self] then EnforceHidden(self) end
            end)
        end
    end
end

local function HideFrame(frame)
    if not frame or not frame.Hide then return end

    hiddenFrames[frame] = true
    if frame.SetAlpha then frame:SetAlpha(0) end
    frame:Hide()

    local data = NSkin:GetSkinData(frame, PROGRESS_STATE)
    if data.hideHooked or not hooksecurefunc then return end
    data.hideHooked = true

    if frame.Show then
        pcall(hooksecurefunc, frame, "Show", function(self)
            if hiddenFrames[self] then
                if self.SetAlpha then self:SetAlpha(0) end
                self:Hide()
            end
        end)
    end

    if frame.SetShown then
        pcall(hooksecurefunc, frame, "SetShown", function(self, shown)
            if shown and hiddenFrames[self] then
                if self.SetAlpha then self:SetAlpha(0) end
                self:Hide()
            end
        end)
    end
end

local function StripRegions(frame)
    if not frame or not frame.GetRegions then return end
    local regions = { frame:GetRegions() }
    for i = 1, #regions do HideTexture(regions[i]) end
end

local widgetArtKeys = {
    "BackgroundGlow", "BGLeft", "BGRight", "BGCenter",
    "BorderLeft", "BorderRight", "BorderCenter", "Spark",
    "GlowLeft", "GlowRight", "GlowCenter",
}

local function StripWidgetArt(bar)
    if not bar then return end
    if bar.GlowPulseAnim and bar.GlowPulseAnim.Stop then
        bar.GlowPulseAnim:Stop()
    end
    for i = 1, #widgetArtKeys do HideTexture(bar[widgetArtKeys[i]]) end
end

local function StripWidgetContainerArt(widget)
    if not widget then return end
    HideTexture(widget.LabelBG)
    HideTexture(widget.LabelBGDivider)
end

local function CreateBackdrop(bar)
    local style = NSkin:GetStyle("progressBar")
    local borderColor = NSkin:GetWindowBorderColor()
    local data = NSkin:GetSkinData(bar, PROGRESS_STATE)
    if data.progressBackground then
        data.progressBackground:SetColorTexture(unpack(style.background))
        NSkin:SetPixelBorderColor(NSkin:GetPixelBorder(bar, PROGRESS_BORDER_KEY),
            unpack(borderColor))
        return
    end

    local background = bar:CreateTexture(nil, "BACKGROUND", nil, -8)
    background:SetAllPoints(bar)
    background:SetColorTexture(unpack(style.background))
    protectedRegions[background] = true
    data.progressBackground = background

    local border = NSkin:CreatePixelBorder(
        bar,
        PROGRESS_BORDER_KEY,
        BORDER_SIZE,
        borderColor,
        true
    )
    if border then
        protectedRegions[border.top] = true
        protectedRegions[border.bottom] = true
        protectedRegions[border.left] = true
        protectedRegions[border.right] = true
    end
end

local function CenterText(bar)
    local style = NSkin:GetStyle("progressBar")
    local function Center(region)
        if region and region.IsObjectType and region:IsObjectType("FontString") then
            region:ClearAllPoints()
            region:SetPoint("CENTER", bar, "CENTER", 0, 1)
            local data = NSkin:GetSkinData(region, PROGRESS_STATE)
            if style.useCustomTextColor then
                if data.blizzardTextRed == nil and region.GetTextColor then
                    data.blizzardTextRed, data.blizzardTextGreen,
                        data.blizzardTextBlue, data.blizzardTextAlpha = region:GetTextColor()
                end
                region:SetTextColor(unpack(style.text))
            elseif data.blizzardTextRed ~= nil then
                region:SetTextColor(data.blizzardTextRed, data.blizzardTextGreen,
                    data.blizzardTextBlue, data.blizzardTextAlpha)
            end
        end
    end

    Center(bar.Label)
    if not bar.GetRegions then return end
    local regions = { bar:GetRegions() }
    for i = 1, #regions do Center(regions[i]) end
end

local ApplyStatusBarColor

local function EnsureAccentColorHook(bar)
    local data = NSkin:GetSkinData(bar, PROGRESS_STATE)
    if data.accentColorHooked then return true end
    if not hooksecurefunc then return false end

    data.blizzardRed, data.blizzardGreen, data.blizzardBlue,
        data.blizzardAlpha = bar:GetStatusBarColor()
    local hooked = pcall(hooksecurefunc, bar, "SetStatusBarColor",
        function(self, red, green, blue, alpha)
            local hookedData = NSkin:GetSkinData(self, PROGRESS_STATE, false)
            if not hookedData or hookedData.applyingColor then return end
            hookedData.blizzardRed, hookedData.blizzardGreen = red, green
            hookedData.blizzardBlue, hookedData.blizzardAlpha = blue, alpha
            local style = NSkin:GetStyle("progressBar")
            if NSkin:IsAccentColorEnabled() or style.useCustomColor then
                ApplyStatusBarColor(self)
            end
        end)
    data.accentColorHooked = hooked == true
    return data.accentColorHooked
end

local function ApplyTexture(bar)
    local data = NSkin:GetSkinData(bar, PROGRESS_STATE)
    if data.applyingTexture then return end
    data.applyingTexture = true

    -- Preserve Blizzard's tint unless the optional shared accent is active.
    bar:SetStatusBarTexture(NSkin:GetStatusBarTexture())
    local fill = bar:GetStatusBarTexture()
    if fill then
        protectedRegions[fill] = true
        fill:Show()
        if fill.SetHorizTile then fill:SetHorizTile(false) end
        if fill.SetVertTile then fill:SetVertTile(false) end
        fill:SetDrawLayer("ARTWORK", 1)

        local fillData = NSkin:GetSkinData(fill, PROGRESS_STATE)
        if not fillData.tileHooked and hooksecurefunc and fill.SetHorizTile then
            fillData.tileHooked = true
            pcall(hooksecurefunc, fill, "SetHorizTile", function(self, tiled)
                local hookedData = NSkin:GetSkinData(self, PROGRESS_STATE)
                if tiled and not hookedData.tileFixing then
                    hookedData.tileFixing = true
                    self:SetHorizTile(false)
                    hookedData.tileFixing = false
                end
            end)
        end
    end

    if data.accentColorHooked or NSkin:IsAccentColorEnabled()
        or NSkin:GetStyle("progressBar").useCustomColor
    then
        ApplyStatusBarColor(bar)
    end
    if data.progressBackground then data.progressBackground:Show() end

    data.applyingTexture = false
end

local function StyleBar(bar)
    if not IsStatusBar(bar) or (bar.IsForbidden and bar:IsForbidden()) then return end

    if not styledBars[bar] then
        styledBars[bar] = true
        local fill = bar:GetStatusBarTexture()
        if fill then protectedRegions[fill] = true end

        StripRegions(bar)
        StripWidgetArt(bar)
        if hooksecurefunc then
            pcall(hooksecurefunc, bar, "SetStatusBarTexture", function(self)
                local data = NSkin:GetSkinData(self, PROGRESS_STATE, false)
                if not data or not data.applyingTexture then ApplyTexture(self) end
            end)
        end
    end

    local height = NSkin:GetStyle("progressBar").height
    if height and height > 0 then bar:SetHeight(height) end
    CreateBackdrop(bar)
    StripWidgetArt(bar)
    ApplyTexture(bar)
    CenterText(bar)
end

ApplyStatusBarColor = function(bar)
    local data = NSkin:GetSkinData(bar, PROGRESS_STATE)
    local red, green, blue, alpha
    local style = NSkin:GetStyle("progressBar")
    if style.useCustomColor then
        if not EnsureAccentColorHook(bar) then return end
        red, green, blue, alpha = unpack(style.color)
    elseif NSkin:IsAccentColorEnabled() then
        if not EnsureAccentColorHook(bar) then return end
        red, green, blue, alpha = unpack(NSkin:GetAccentColor())
    else
        red, green, blue, alpha = data.blizzardRed, data.blizzardGreen,
            data.blizzardBlue, data.blizzardAlpha
    end
    if red == nil then return end

    data.applyingColor = true
    bar:SetStatusBarColor(red, green, blue, alpha)
    data.applyingColor = false
end

local scenarioArtKeys = {
    "GlowTexture", "HeaderIconGlow", "HeaderBackground", "Background",
    "BackgroundTexture", "FinalBG",
}

local function HideScenarioArt(widget)
    local function HideKnownArt(container)
        if not container then return end
        for i = 1, #scenarioArtKeys do
            local art = container[scenarioArtKeys[i]]
            if art and art.IsObjectType and art:IsObjectType("Texture") then
                HideTexture(art)
            elseif art and art.Hide then
                HideFrame(art)
            end
        end
        HideFrame(container.Frame)
        HideFrame(container.FrontModelScene)
        HideFrame(container.BackModelScene)
    end

    local current = widget
    for _ = 1, 6 do
        if not current then break end
        HideKnownArt(current)
        HideKnownArt(current.WidgetContainer)
        HideKnownArt(current.widgetContainer)
        current = current.GetParent and current:GetParent()
    end
end

local function AnchorScenarioTimer(widget)
    local bar = widget and widget.TimerBar
    local data = IsStatusBar(bar) and NSkin:GetSkinData(bar, PROGRESS_STATE) or nil
    if not data or data.anchorFixing then return end
    data.anchorFixing = true
    bar:ClearAllPoints()
    bar:SetPoint("BOTTOM", widget, "BOTTOM", 0, SCENARIO_TIMER_BAR_Y)
    data.anchorFixing = false
end

local function SkinScenarioTimer(widget)
    local bar = widget and widget.TimerBar
    if not IsStatusBar(bar) then return end

    HideScenarioArt(widget)
    StyleBar(bar)
    local data = NSkin:GetSkinData(bar, PROGRESS_STATE)
    data.scenarioOwner = widget

    if not data.anchorHooked and hooksecurefunc then
        data.anchorHooked = true
        pcall(hooksecurefunc, bar, "SetPoint", function(self)
            local hookedData = NSkin:GetSkinData(self, PROGRESS_STATE, false)
            if hookedData and not hookedData.anchorFixing then
                AnchorScenarioTimer(hookedData.scenarioOwner)
            end
        end)
    end
    AnchorScenarioTimer(widget)
end

local function InstallHooks()
    local statusMixin = _G.UIWidgetTemplateStatusBarMixin
    if not statusHookInstalled and statusMixin and type(statusMixin.Setup) == "function" then
        statusHookInstalled = true
        hooksecurefunc(statusMixin, "Setup", function(widget)
            if widget.IsForbidden and widget:IsForbidden() then return end
            StripWidgetContainerArt(widget)
            if IsStatusBar(widget.Bar) then StyleBar(widget.Bar) end
        end)
    end

    local scenarioMixin = _G.UIWidgetTemplateScenarioHeaderTimerMixin
    if not scenarioHookInstalled and scenarioMixin and type(scenarioMixin.Setup) == "function" then
        scenarioHookInstalled = true
        hooksecurefunc(scenarioMixin, "Setup", function(widget)
            if widget.IsForbidden and widget:IsForbidden() then return end
            SkinScenarioTimer(widget)
        end)
    end
end

local objectiveTrackerNames = {
    "ScenarioObjectiveTracker",
    "UIWidgetObjectiveTracker",
    "CampaignQuestObjectiveTracker",
    "QuestObjectiveTracker",
    "AdventureObjectiveTracker",
    "AchievementObjectiveTracker",
    "MonthlyActivitiesObjectiveTracker",
    "ProfessionsRecipeTracker",
    "BonusObjectiveTracker",
    "WorldQuestObjectiveTracker",
    "InitiativeTasksObjectiveTracker",
}

local function StyleTrackerProgressBar(tracker, key)
    local progressBar = tracker.usedProgressBars and tracker.usedProgressBars[key]
    local bar = progressBar and progressBar.Bar
    if IsStatusBar(bar) then StyleBar(bar) end
end

local function StyleTrackerTimerBar(tracker, key)
    local timerBar = tracker.usedTimerBars and tracker.usedTimerBars[key]
    local bar = timerBar and timerBar.Bar
    if IsStatusBar(bar) then StyleBar(bar) end
end

local function StyleExistingTrackerBars(tracker)
    if tracker.usedProgressBars then
        for key in pairs(tracker.usedProgressBars) do
            StyleTrackerProgressBar(tracker, key)
        end
    end
    if tracker.usedTimerBars then
        for key in pairs(tracker.usedTimerBars) do
            StyleTrackerTimerBar(tracker, key)
        end
    end
end

local function InstallObjectiveTrackerHooks()
    if not hooksecurefunc then return end

    for i = 1, #objectiveTrackerNames do
        local tracker = _G[objectiveTrackerNames[i]]
        if tracker and not hookedObjectiveTrackers[tracker] then
            hookedObjectiveTrackers[tracker] = true

            if type(tracker.GetProgressBar) == "function" then
                hooksecurefunc(tracker, "GetProgressBar", StyleTrackerProgressBar)
            end
            if type(tracker.GetTimerBar) == "function" then
                hooksecurefunc(tracker, "GetTimerBar", StyleTrackerTimerBar)
            end

            StyleExistingTrackerBars(tracker)
        end
    end
end

local function SkinTooltipProgressBar(tooltip)
    if not tooltip or not tooltip.progressBarPool then return end
    if tooltip.IsForbidden and tooltip:IsForbidden() then return end

    local pooled = tooltip.progressBarPool:GetNextActive()
    local bar = pooled and pooled.Bar
    if IsStatusBar(bar) then StyleBar(bar) end
end

local function SkinTooltipStatusBar(tooltip)
    if not tooltip or not tooltip.statusBarPool then return end
    if tooltip.IsForbidden and tooltip:IsForbidden() then return end

    local bar = tooltip.statusBarPool:GetNextActive()
    if IsStatusBar(bar) then StyleBar(bar) end
end

local function InstallTooltipHooks()
    if tooltipHooksInstalled or not hooksecurefunc then return end
    if type(_G.GameTooltip_ShowProgressBar) ~= "function"
        or type(_G.GameTooltip_ShowStatusBar) ~= "function"
    then
        return
    end

    tooltipHooksInstalled = true
    hooksecurefunc("GameTooltip_ShowProgressBar", SkinTooltipProgressBar)
    hooksecurefunc("GameTooltip_ShowStatusBar", SkinTooltipStatusBar)
end

function ProgressBars:Scan()
    if not NSkin:IsModuleEnabled("BlizzardProgressBars") then return end
    scanPending = false
    InstallHooks()
    InstallObjectiveTrackerHooks()
    InstallTooltipHooks()

    -- A rescan only revisits bars already identified by the exact widget
    -- mixins. It never walks arbitrary frame trees.
    for bar in pairs(styledBars) do
        if IsStatusBar(bar) then
            StripWidgetArt(bar)
            ApplyTexture(bar)
            CenterText(bar)
        end
    end
end

function ProgressBars:QueueScan()
    if not NSkin:IsModuleEnabled("BlizzardProgressBars") then return end
    if scanPending then return end
    scanPending = true
    C_Timer.After(0, function() self:Scan() end)
end

function ProgressBars:RefreshTheme()
    for bar in pairs(styledBars) do
        if IsStatusBar(bar) then StyleBar(bar) end
    end
end

function ProgressBars:Debug()
    local count = 0
    for bar in pairs(styledBars) do
        count = count + 1
        print(count, bar.GetName and bar:GetName() or "<anonymous>", tostring(bar))
    end

    local trackerCount = 0
    for _ in pairs(hookedObjectiveTrackers) do trackerCount = trackerCount + 1 end

    NSkin:Print(("hooks: status=%s, scenario=%s, tooltip=%s, trackers=%d; styled bars=%d"):format(
        statusHookInstalled and "yes" or "no",
        scenarioHookInstalled and "yes" or "no",
        tooltipHooksInstalled and "yes" or "no",
        trackerCount,
        count
    ))
end

local function WarnAboutLegacyAddon()
    if conflictWarningShown then return end

    local loaded = false
    if _G.C_AddOns and _G.C_AddOns.IsAddOnLoaded then
        loaded = _G.C_AddOns.IsAddOnLoaded("BlizzardProgressBarSkin")
    elseif _G.IsAddOnLoaded then
        loaded = _G.IsAddOnLoaded("BlizzardProgressBarSkin")
    end

    if loaded then
        conflictWarningShown = true
        NSkin:Print("BlizzardProgressBarSkin is also enabled. Disable the old addon to prevent competing status-bar hooks.")
    end
end

NSkin:RegisterModuleInitializer("BlizzardProgressBars", function()
    NSkin:RegisterEvent("PLAYER_ENTERING_WORLD", function() ProgressBars:QueueScan() end)
    NSkin:RegisterEvent("PLAYER_ENTERING_WORLD", WarnAboutLegacyAddon)

    local relevantAddons = {
        Blizzard_UIWidgets = true,
        Blizzard_ScenarioObjectiveTracker = true,
        Blizzard_ObjectiveTracker = true,
        Blizzard_SharedTooltip = true,
    }

    NSkin:RegisterEvent("ADDON_LOADED", function(_, addonName)
        InstallHooks()
        InstallObjectiveTrackerHooks()
        InstallTooltipHooks()
        if relevantAddons[addonName] then ProgressBars:QueueScan() end
    end)

    InstallHooks()
    InstallObjectiveTrackerHooks()
    InstallTooltipHooks()
end)
