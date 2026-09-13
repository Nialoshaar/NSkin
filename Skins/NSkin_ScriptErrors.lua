local _, NSkin = ...

local ScriptErrorsSkin = NSkin:NewModule("ScriptErrors")

local IDs = {
    Scope = "ScriptErrors",
    Window = "ScriptErrors.Window",
    HeaderControls = "ScriptErrors.HeaderControls",
    ErrorText = "ScriptErrors.ErrorText",
    ScrollBar = "ScriptErrors.ScrollBar",
    IndexLabel = "ScriptErrors.IndexLabel",
    Reload = "ScriptErrors.Reload",
    PreviousError = "ScriptErrors.PreviousError",
    NextError = "ScriptErrors.NextError",
    Close = "ScriptErrors.Close",
}

local initialized = false
local showHooked = false
local ERROR_TEXT_SURFACE_BASELINE = IDs.ErrorText .. ":Surface"

NSkin:RegisterAppearanceScope(IDs.Scope, {
    label = "Script Errors",
})

local function IsVisible(target)
    return target and target.IsVisible and target:IsVisible() or false
end

local function RefreshElement(element)
    if element then NSkin:RefreshTypedElementAppearance(element) end
    return element
end

local function SuppressLegacyWindowArtwork(frame)
    local data = NSkin:GetSkinData(frame, "scriptErrorsDecorations")
    data.states = data.states or {}
    for _, region in pairs({
        frame.TitleBG or _G.ScriptErrorsFrameTitleBG,
        frame.DialogBG or _G.ScriptErrorsFrameDialogBG,
        frame.Top or _G.ScriptErrorsFrameTop,
        frame.Bottom or _G.ScriptErrorsFrameBottom,
        frame.Left or _G.ScriptErrorsFrameLeft,
        frame.Right or _G.ScriptErrorsFrameRight,
        frame.TopLeft or _G.ScriptErrorsFrameTopLeft,
        frame.TopRight or _G.ScriptErrorsFrameTopRight,
        frame.BottomLeft or _G.ScriptErrorsFrameBottomLeft
            or _G.ScriptErrorsFrameBotLeft,
        frame.BottomRight or _G.ScriptErrorsFrameBottomRight
            or _G.ScriptErrorsFrameBotRight,
    }) do
        if region then
            local state = data.states[region]
            if not state then
                state = {}
                data.states[region] = state
            end
            state.active = true
            local function Conceal()
                if not state.active or state.applying then return end
                state.applying = true
                if region.SetAlpha then region:SetAlpha(0) end
                if region.Hide then region:Hide() end
                state.applying = nil
            end
            Conceal()
            if not state.hooked and _G.hooksecurefunc then
                for _, method in ipairs({ "SetAlpha", "SetShown", "Show" }) do
                    if type(region[method]) == "function" then
                        pcall(_G.hooksecurefunc, region, method, Conceal)
                    end
                end
                state.hooked = true
            end
        end
    end
end

local function RegisterTyped(frame, typeID, id, label, target, priority,
    options)
    if not target then return false end
    options = options or {}
    local element = NSkin:RegisterTypedElement(typeID, {
        id = id,
        module = "ScriptErrors",
        appearanceWindowID = IDs.Scope,
        label = label,
        window = frame,
        target = target,
        priority = priority,
        skinOptions = options.skinOptions,
        preserveTexture = options.preserveTexture,
        pixelBorderTargets = options.pixelBorderTargets,
        highlightRegions = { target },
        isEditable = function()
            return IsVisible(frame) and IsVisible(target)
        end,
    })
    return RefreshElement(element) ~= nil
end

local function LayoutErrorTextSurface(frame, scrollFrame)
    if not scrollFrame or not scrollFrame.ClearAllPoints
        or not scrollFrame.SetPoint
    then return end
    NSkin:CaptureComponentBaseline(ERROR_TEXT_SURFACE_BASELINE, scrollFrame, {
        points = true,
        canCapture = function(target)
            return target.GetNumPoints and target:GetNumPoints() > 0
        end,
    })
    NSkin:MarkComponentGeometryModified(
        ERROR_TEXT_SURFACE_BASELINE, "points", true)
    scrollFrame:ClearAllPoints()
    scrollFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -30)
    scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -29, 48)
end

local function SuppressNativeButtonText(button)
    if not button or not button.GetFontString then return end
    local data = NSkin:GetSkinData(button, "scriptErrorsButtonText")
    local nativeText = button:GetFontString()
    local componentData = NSkin:GetSkinData(button, "components", false)
    if not nativeText or nativeText == (componentData and componentData.label) then
        return
    end
    data.nativeText = nativeText
    local function Conceal()
        local state = NSkin:GetSkinData(
            button, "scriptErrorsButtonText", false)
        if not state or state.applying or not state.nativeText then return end
        state.applying = true
        state.nativeText:SetAlpha(0)
        state.applying = nil
    end
    Conceal()
    if not data.hooked and _G.hooksecurefunc then
        _G.hooksecurefunc(nativeText, "SetAlpha", Conceal)
        data.hooked = true
    end
end

function ScriptErrorsSkin:ApplyWindowChrome(frame)
    SuppressLegacyWindowArtwork(frame)
    NSkin:SkinStandardWindowChrome({
        frame = frame,
        appearanceWindowID = IDs.Scope,
        elementID = IDs.Window,
        headerControlsID = IDs.HeaderControls,
        title = frame.TitleContainer and frame.TitleContainer.TitleText
            or frame.Title or frame.TitleText
            or _G.ScriptErrorsFrameTitleText,
        closeButton = frame.CloseButton or _G.ScriptErrorsFrameCloseButton
            or _G.ScriptErrorsFrameClose,
    })
    NSkin:RegisterSkinningElement(IDs.Window, {
        label = "Script Errors window",
        kind = "WINDOW",
        module = "ScriptErrors",
        appearanceWindowID = IDs.Scope,
        window = frame,
        target = frame,
        priority = 0,
        draggable = false,
    })
    return true
end

function ScriptErrorsSkin:ApplyErrorText(frame)
    local scrollFrame = frame.ScrollFrame
    LayoutErrorTextSurface(frame, scrollFrame)
    return RegisterTyped(frame, "EDIT_BOX", IDs.ErrorText,
        "Error text", scrollFrame and scrollFrame.Text, 20, {
            skinOptions = { surface = scrollFrame },
            pixelBorderTargets = { scrollFrame },
        })
end

function ScriptErrorsSkin:ApplyScrollBar(frame)
    local scrollFrame = frame.ScrollFrame
    local scrollBar = scrollFrame and scrollFrame.ScrollBar
    if not scrollBar then return false end
    local element = NSkin:RegisterScrollBar({
        id = IDs.ScrollBar,
        module = "ScriptErrors",
        appearanceWindowID = IDs.Scope,
        label = "Error text scroll bar",
        window = frame,
        target = scrollBar,
        priority = 21,
        highlightRegions = { scrollBar },
        isEditable = function()
            return IsVisible(frame) and IsVisible(scrollBar)
        end,
    })
    return RefreshElement(element) ~= nil
end

function ScriptErrorsSkin:ApplyIndexLabel(frame)
    local label = frame.IndexLabel
    if not label then return false end
    local element = NSkin:RegisterTextElement({
        id = IDs.IndexLabel,
        module = "ScriptErrors",
        appearanceWindowID = IDs.Scope,
        label = "Error index label",
        window = frame,
        target = label,
        priority = 30,
        highlightRegions = { label },
        isEditable = function()
            return IsVisible(frame) and IsVisible(label)
        end,
    })
    return RefreshElement(element) ~= nil
end

function ScriptErrorsSkin:ApplyButtons(frame)
    local applied = false
    local reload = frame.Reload
    if reload then
        local element = NSkin:RegisterActionButton({
            id = IDs.Reload,
            module = "ScriptErrors",
            appearanceWindowID = IDs.Scope,
            label = "Reload UI button",
            window = frame,
            target = reload,
            priority = 40,
            highlightRegions = { reload },
            isEditable = function()
                return IsVisible(frame) and IsVisible(reload)
            end,
        })
        applied = RefreshElement(element) ~= nil or applied
    end

    local function RegisterNavigationButton(id, label, button, priority,
        rotation)
        if not button then return false end
        local data = NSkin:GetSkinData(button, "scriptErrorsNavigation")
        if not data.arrow then
            data.arrow = button:CreateTexture(nil, "OVERLAY", nil, 2)
            data.arrow:SetSize(14, 14)
            data.arrow:SetPoint("CENTER")
            data.arrow:SetTexture(NSkin.mediaPath .. "angle-small-down.png")
            data.arrow:SetRotation(rotation)
            NSkin:ConfigureOwnedPixelTexture(data.arrow)
        end
        local function RefreshArrow()
            local enabled = not button.IsEnabled or button:IsEnabled()
            local value = enabled and 1 or 0.45
            data.arrow:SetVertexColor(value, value, value, 1)
            data.arrow:Show()
        end
        if not data.hooked and button.HookScript then
            button:HookScript("OnEnable", RefreshArrow)
            button:HookScript("OnDisable", RefreshArrow)
            button:HookScript("OnShow", RefreshArrow)
            data.hooked = true
        end
        local registered = RegisterTyped(frame, "BUTTON", id, label,
            button, priority, { preserveTexture = data.arrow })
        RefreshArrow()
        return registered
    end

    applied = RegisterNavigationButton(IDs.PreviousError,
        "Previous error button", frame.PreviousError, 41,
        -math.pi / 2) or applied
    applied = RegisterNavigationButton(IDs.NextError,
        "Next error button", frame.NextError, 42,
        math.pi / 2) or applied
    local closeButton = frame.Close
    if closeButton then
        local closeLabel = closeButton.GetText and closeButton:GetText() or "Close"
        applied = RegisterTyped(frame, "BUTTON", IDs.Close, "Close button",
            closeButton, 43, {
                skinOptions = { label = closeLabel },
            }) or applied
        SuppressNativeButtonText(closeButton)
    end
    return applied
end

function ScriptErrorsSkin:Apply()
    local frame = _G.ScriptErrorsFrame
    if not frame then return false end
    local applied = self:ApplyWindowChrome(frame)
    applied = self:ApplyErrorText(frame) or applied
    applied = self:ApplyScrollBar(frame) or applied
    applied = self:ApplyIndexLabel(frame) or applied
    applied = self:ApplyButtons(frame) or applied
    return applied
end

function ScriptErrorsSkin:Initialize()
    local frame = _G.ScriptErrorsFrame
    if not frame then return false end
    if not showHooked and frame.HookScript then
        frame:HookScript("OnShow", function()
            ScriptErrorsSkin:Apply()
        end)
        showHooked = true
    end
    initialized = true
    return self:Apply()
end

function ScriptErrorsSkin:RefreshAppearance()
    if initialized then self:Apply() end
end

NSkin:RegisterWindowSkin({
    key = IDs.Window,
    module = "ScriptErrors",
    addon = "Blizzard_ScriptErrorsFrame",
    apply = function()
        return ScriptErrorsSkin:Initialize()
    end,
})
