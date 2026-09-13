local _, NSkin = ...

local previewState

local function CaptureFramePoints(frame)
    local points = {}
    if frame and frame.GetNumPoints then
        for index = 1, frame:GetNumPoints() do
            points[index] = { frame:GetPoint(index) }
        end
    end
    return points
end

local function RestoreFramePoints(frame, points)
    if not frame or not frame.ClearAllPoints or not frame.SetPoint then return end
    frame:ClearAllPoints()
    for index = 1, #(points or {}) do
        frame:SetPoint(unpack(points[index]))
    end
end

local function HasActiveLFGQueue()
    if type(_G.GetLFGProposal) == "function" then
        local proposalExists = _G.GetLFGProposal()
        if proposalExists then return true end
    end
    if type(_G.GetLFGMode) ~= "function" then return false end
    for category = 1, (_G.NUM_LE_LFG_CATEGORYS or 3) do
        local mode = _G.GetLFGMode(category)
        if mode == "queued" or mode == "rolecheck" or mode == "proposal"
            or mode == "suspended"
        then return true end
    end
    return false
end

local function FinishPreview()
    local state = previewState
    if not state then return end
    previewState = nil

    local popup = state.popup
    popup:SetScript("OnShow", state.onShow)
    popup:SetScript("OnHide", state.onHide)
    popup:SetHeight(state.height)
    RestoreFramePoints(popup, state.points)
    for button, script in pairs(state.buttonScripts) do
        button:SetScript("OnClick", script)
    end
end

local function HidePreview()
    local state = previewState
    if not state then return false end
    if state.popup:IsShown() then
        state.popup:Hide()
    else
        FinishPreview()
    end
    return true
end

local function SetPreviewButton(state, button, text)
    if not button then return end
    state.buttonScripts[button] = button:GetScript("OnClick")
    if text and button.SetText then button:SetText(text) end
    if button.Enable then button:Enable() end
    button:SetScript("OnClick", HidePreview)
end

function NSkin:ToggleLFGQueuePopPreview()
    if HidePreview() then
        self:Print("LFG queue pop preview hidden.")
        return true
    end
    if _G.InCombatLockdown and _G.InCombatLockdown() then
        self:Print("The LFG queue pop preview is unavailable during combat.")
        return false
    end
    if HasActiveLFGQueue() then
        self:Print("The LFG queue pop preview is unavailable while queued.")
        return false
    end

    local addons = _G.C_AddOns
    if addons and addons.IsAddOnLoaded
        and not addons.IsAddOnLoaded("Blizzard_GroupFinder")
    then
        local loaded, reason = addons.LoadAddOn("Blizzard_GroupFinder")
        if not loaded then
            self:Print("Unable to load the Group Finder UI: "
                .. tostring(reason or "unknown error"))
            return false
        end
    end

    local popup = _G.LFGDungeonReadyPopup
    local dialog = _G.LFGDungeonReadyDialog
    if not popup or not dialog then
        self:Print("The LFG queue pop preview is unavailable.")
        return false
    end
    if popup:IsShown() then
        self:Print("The LFG queue pop is already visible.")
        return false
    end

    local state = {
        popup = popup,
        onShow = popup:GetScript("OnShow"),
        onHide = popup:GetScript("OnHide"),
        height = popup:GetHeight(),
        points = CaptureFramePoints(popup),
        buttonScripts = {},
    }
    previewState = state
    popup:SetScript("OnShow", nil)
    popup:SetScript("OnHide", FinishPreview)
    popup:ClearAllPoints()
    popup:SetPoint("CENTER", _G.UIParent, "CENTER")
    popup:SetHeight(193)

    local status = _G.LFGDungeonReadyStatus
    if status then status:Hide() end
    dialog:Show()
    if dialog.background then
        dialog.background:SetTexture(
            "Interface\\LFGFrame\\UI-LFG-BACKGROUND-RANDOMDUNGEON")
        dialog.background:SetDrawLayer("BACKGROUND")
        dialog.background:SetWidth(294)
        dialog.background:SetTexCoord(0, 1, 0, 118 / 128)
    end
    if dialog.label then
        dialog.label:SetText(_G.RANDOM_DUNGEON_IS_READY
            or "Your Random Dungeon group is ready!")
    end
    if dialog.instanceInfo then dialog.instanceInfo:Hide() end
    if dialog.randomInProgress then dialog.randomInProgress:Hide() end

    local roleIcon = _G.LFGDungeonReadyDialogRoleIcon
    local roleTexture = _G.LFGDungeonReadyDialogRoleIconTexture
    local roleDescription = _G.LFGDungeonReadyDialogYourRoleDescription
    local roleLabel = _G.LFGDungeonReadyDialogRoleLabel
    local leaderIcon = _G.LFGDungeonReadyDialogRoleIconLeaderIcon
    if roleIcon then roleIcon:Show() end
    if roleDescription then roleDescription:Show() end
    if roleLabel then roleLabel:SetText(_G.TANK or "Tank") end
    if roleTexture and type(_G.GetIconForRole) == "function" then
        roleTexture:SetAtlas(_G.GetIconForRole("TANK", false),
            _G.TextureKitConstants and _G.TextureKitConstants.IgnoreAtlasSize)
    end
    if leaderIcon then leaderIcon:Hide() end

    local rewards = _G.LFGDungeonReadyDialogRewardsFrame
    if rewards then
        rewards:ClearAllPoints()
        if roleIcon then
            rewards:SetPoint("BOTTOMLEFT", roleIcon, "BOTTOMRIGHT", 19, 14)
        end
        rewards:Show()
    end
    local rewardsLabel = _G.LFGDungeonReadyDialogRewardsFrameLabel
    if rewardsLabel then rewardsLabel:Show() end
    local previewIcons = {
        "Interface\\Icons\\INV_Misc_Coin_02",
        "Interface\\Icons\\INV_Misc_Bag_10",
    }
    for index = 1, 2 do
        local reward = _G["LFGDungeonReadyDialogRewardsFrameReward" .. index]
        if reward then
            reward.rewardType = nil
            if reward.texture then reward.texture:SetTexture(previewIcons[index]) end
            reward:Show()
        end
    end

    SetPreviewButton(state, dialog.enterButton,
        _G.ENTER_LFG or "Enter Dungeon")
    SetPreviewButton(state, dialog.leaveButton,
        _G.LEAVE_QUEUE or "Leave Queue")
    SetPreviewButton(state, _G.LFGDungeonReadyDialogCloseButton)
    popup:Show()
    self:Print("LFG queue pop preview shown; run /nskin lfgpop again to hide it.")
    return true
end
