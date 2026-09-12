local _, NSkin = ...

local DeathRecapSkin = NSkin:NewModule("DeathRecap")

local IDs = {
    Scope = "DeathRecap",
    Window = "DeathRecap.Window",
    HeaderControls = "DeathRecap.HeaderControls",
    CloseButton = "DeathRecap.CloseButton",
    ScrollBar = "DeathRecap.ScrollBar",
    Rows = "DeathRecap.Rows",
}

local initialized = false
local showHooked = false
local scrollBoxHooked = false
local rowsRegistered = false

NSkin:RegisterAppearanceScope(IDs.Scope, {
    label = "Death Recap",
})

local function IsVisible(target)
    return target and target.IsVisible and target:IsVisible() or false
end

local function GetScrollBox(frame)
    return frame and frame.ScrollBox
end

local function GetVisibleRows(frame)
    local rows = {}
    NSkin:ForEachScrollBoxFrame(GetScrollBox(frame), function(row)
        if IsVisible(row) then rows[#rows + 1] = row end
    end)
    return rows
end

local function GetStyles()
    local styles = {
        row = NSkin:GetAppearanceStyle("row", IDs.Scope, IDs.Rows),
        icon = NSkin:GetAppearanceStyle("icon", IDs.Scope, IDs.Rows),
        text = NSkin:GetAppearanceStyle("text", IDs.Scope, IDs.Rows),
    }
    styles.rowBorder = NSkin:GetAppearanceBorderColor(
        "row", styles.row, IDs.Scope, IDs.Rows)
    styles.iconBorder = NSkin:GetAppearanceBorderColor(
        "icon", styles.icon, IDs.Scope, IDs.Rows)
    return styles
end

local function GetRowTexts(row)
    local spellInfo = row and row.SpellInfo
    local damageInfo = row and row.DamageInfo
    return {
        spellInfo and spellInfo.Name,
        spellInfo and spellInfo.Caster,
        damageInfo and damageInfo.Amount,
        damageInfo and damageInfo.AmountLarge,
    }
end

local function GetRowIcon(row)
    local spellInfo = row and row.SpellInfo
    if not spellInfo or not spellInfo.Icon then return nil end
    return spellInfo, spellInfo.Icon, spellInfo.IconBorder
end

local function SuppressWindowBorders(frame)
    local data = NSkin:GetSkinData(frame, "deathRecapDecorations")
    data.states = data.states or {}
    for _, region in pairs({
        _G.DeathRecapFrameBorderLeft,
        _G.DeathRecapFrameBorderTop,
        _G.DeathRecapFrameBorderRight,
        _G.DeathRecapFrameBorderBottom,
        _G.DeathRecapFrameBorderBottomLeft
            or _G.DeathRecapFrameBoderBottomLeft,
        _G.DeathRecapFrameBorderBottomRight
            or _G.DeathRecapFrameBoderBottomRight,
        _G.DeathRecapFrameBorderTopLeft
            or _G.DeathRecapFrameBoderTopLeft,
        _G.DeathRecapFrameBorderTopRight
            or _G.DeathRecapFrameBoderTopRight,
        frame.BackgroundInnerGlow,
        frame.Divider or _G.DeathRecapFrameDivider,
    }) do
        if region then
            local state = data.states[region]
            if not state then
                state = {
                    alpha = region.GetAlpha and region:GetAlpha() or 1,
                    shown = region.IsShown and region:IsShown() or nil,
                }
                data.states[region] = state
            end
            state.active = true
            local function Conceal()
                if not state.active or state.applying then return end
                state.applying = true
                if region.SetAlpha then region:SetAlpha(0) end
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

function DeathRecapSkin:StyleRow(row, styles)
    if not row then return false end
    styles = styles or GetStyles()
    local applied = NSkin:SkinRow(row, {
        style = styles.row,
        border = styles.rowBorder,
        hoverRegion = row.GetHighlightTexture and row:GetHighlightTexture()
            or row.HighlightTexture,
        getHovered = function(target)
            return target and target.IsMouseOver
                and target:IsMouseOver() or false
        end,
    }) ~= nil

    local iconTarget, icon, iconBorder = GetRowIcon(row)
    if iconTarget and icon then
        local nativeDecorations = {}
        if iconBorder then
            nativeDecorations[#nativeDecorations + 1] = iconBorder
        end
        applied = NSkin:SkinIcon(iconTarget, {
            style = styles.icon,
            borderColor = styles.iconBorder,
            texture = icon,
            borderOwner = iconTarget,
            nativeDecorationRegions = nativeDecorations,
        }) == true or applied
    end

    for _, target in pairs(GetRowTexts(row)) do
        if target then
            applied = NSkin:SkinText(target, styles.text) == true or applied
        end
    end
    return applied
end

function DeathRecapSkin:ApplyWindowChrome(frame)
    SuppressWindowBorders(frame)
    NSkin:SkinStandardWindowChrome({
        frame = frame,
        appearanceWindowID = IDs.Scope,
        elementID = IDs.Window,
        headerControlsID = IDs.HeaderControls,
        title = frame.TitleContainer and frame.TitleContainer.TitleText
            or frame.Title or _G.DeathRecapFrameTitle,
        closeButton = frame.CloseXButton
            or _G.DeathRecapFrameCloseXButton,
    })
    NSkin:RegisterSkinningElement(IDs.Window, {
        label = "Death Recap window",
        kind = "WINDOW",
        module = "DeathRecap",
        appearanceWindowID = IDs.Scope,
        window = frame,
        target = frame,
        priority = 0,
        draggable = false,
    })
    return true
end

function DeathRecapSkin:ApplyCloseButton(frame)
    local button = frame.CloseButton
    if not button then return false end
    local element = NSkin:RegisterTypedElement("BUTTON", {
        id = IDs.CloseButton,
        module = "DeathRecap",
        appearanceWindowID = IDs.Scope,
        label = "Death Recap close button",
        window = frame,
        target = button,
        priority = 15,
        highlightRegions = { button },
        isEditable = function()
            return IsVisible(frame) and IsVisible(button)
        end,
    })
    if element then NSkin:RefreshTypedElementAppearance(element) end
    if button.ClearAllPoints and button.SetPoint then
        button:ClearAllPoints()
        button:SetPoint("BOTTOM", frame, "BOTTOM", 0, 14)
    end
    return element ~= nil
end

function DeathRecapSkin:ApplyScrollBar(frame)
    local scrollBar = frame.ScrollBar
        or (GetScrollBox(frame) and GetScrollBox(frame).ScrollBar)
    if not scrollBar then return false end
    local element = NSkin:RegisterScrollBar({
        id = IDs.ScrollBar,
        module = "DeathRecap",
        appearanceWindowID = IDs.Scope,
        label = "Death Recap scroll bar",
        window = frame,
        target = scrollBar,
        priority = 20,
        highlightRegions = { scrollBar },
        isEditable = function()
            return IsVisible(frame) and IsVisible(scrollBar)
        end,
    })
    if element then NSkin:RefreshTypedElementAppearance(element) end
    return element ~= nil
end

function DeathRecapSkin:ApplyRows(frame)
    local scrollBox = GetScrollBox(frame)
    if not scrollBox then return false end
    local styles = GetStyles()
    local applied = false
    NSkin:ForEachScrollBoxFrame(scrollBox, function(row)
        applied = self:StyleRow(row, styles) or applied
    end)

    if not rowsRegistered then
        local function RefreshRows()
            return DeathRecapSkin:ApplyRows(frame)
        end
        rowsRegistered = NSkin:RegisterSkinningElement(IDs.Rows, {
            module = "DeathRecap",
            appearanceWindowID = IDs.Scope,
            label = "Death Recap event rows",
            kind = "ROW",
            window = frame,
            target = scrollBox,
            priority = 30,
            draggable = false,
            appearanceStyles = { "text", "icon" },
            appearanceTypeIDs = { "TEXT", "ICON" },
            highlightRegions = function()
                return GetVisibleRows(frame)
            end,
            pixelBorderTargets = function()
                return GetVisibleRows(frame)
            end,
            editorOptions = {
                { id = "shared.rowAppearance", label = "Rows",
                    category = "CUSTOMIZE" },
                { id = "shared.textAppearance", label = "Row text",
                    category = "CUSTOMIZE" },
                { id = "shared.iconAppearance", label = "Row icons",
                    category = "CUSTOMIZE" },
            },
            refreshAppearance = RefreshRows,
            refreshLayout = RefreshRows,
            isEditable = function()
                return IsVisible(frame) and #GetVisibleRows(frame) > 0
            end,
        }) == true
    end
    if rowsRegistered then
        NSkin:NotifySkinningElementBoundsChanged(IDs.Rows)
    end
    return applied or rowsRegistered
end

function DeathRecapSkin:HookScrollBox(frame)
    local scrollBox = GetScrollBox(frame)
    if not scrollBox or scrollBoxHooked then return false end
    local events = _G.ScrollBoxListMixin and _G.ScrollBoxListMixin.Event
    if scrollBox.RegisterCallback and events
        and events.OnInitializedFrame
    then
        scrollBox:RegisterCallback(events.OnInitializedFrame,
            function(_, row)
                DeathRecapSkin:StyleRow(row)
                NSkin:NotifySkinningElementBoundsChanged(IDs.Rows)
            end, self)
        scrollBoxHooked = true
    elseif _G.hooksecurefunc and type(scrollBox.Update) == "function" then
        _G.hooksecurefunc(scrollBox, "Update", function()
            DeathRecapSkin:ApplyRows(frame)
        end)
        scrollBoxHooked = true
    end
    return scrollBoxHooked
end

function DeathRecapSkin:Apply()
    local frame = _G.DeathRecapFrame
    if not frame then return false end
    local applied = self:ApplyWindowChrome(frame)
    applied = self:ApplyCloseButton(frame) or applied
    applied = self:ApplyScrollBar(frame) or applied
    applied = self:ApplyRows(frame) or applied
    return applied
end

function DeathRecapSkin:Initialize()
    local frame = _G.DeathRecapFrame
    if not frame then return false end
    if not showHooked and frame.HookScript then
        frame:HookScript("OnShow", function()
            DeathRecapSkin:Apply()
        end)
        showHooked = true
    end
    self:HookScrollBox(frame)
    initialized = true
    return self:Apply()
end

function DeathRecapSkin:RefreshAppearance()
    if initialized then self:Apply() end
end

NSkin:RegisterWindowSkin({
    key = "DeathRecap.Window",
    module = "DeathRecap",
    addon = "Blizzard_DeathRecap",
    apply = function()
        return DeathRecapSkin:Initialize()
    end,
})
