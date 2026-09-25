local _, NSkin = ...

local BarberShopSkin = NSkin:NewModule("BarberShop")

local IDs = {
    Scope = "BarberShop",
    Window = "BarberShop.Window",
    BodyTypes = "BarberShop.BodyTypes",
    AlteredForms = "BarberShop.AlteredForms",
    FormsDropdown = "BarberShop.FormsDropdown",
    Categories = "BarberShop.Categories",
    Randomize = "BarberShop.Randomize",
    CameraControls = "BarberShop.CameraControls",
    Options = {
        Dropdowns = "BarberShop.Options.Dropdowns",
        Sliders = "BarberShop.Options.Sliders",
        Checkboxes = "BarberShop.Options.Checkboxes",
        Labels = "BarberShop.Options.Labels",
        Steppers = "BarberShop.Options.Steppers",
    },
    Reset = "BarberShop.Reset",
    Cancel = "BarberShop.Cancel",
    Accept = "BarberShop.Accept",
}

local initialized = false
local lifecycleHooked = false
local applyPending = false
local registeredGroups = {}

NSkin:RegisterAppearanceScope(IDs.Scope, {
    label = "Barber Shop",
})

local function IsVisible(target)
    return target and target.IsVisible and target:IsVisible() or false
end

local function IsForbidden(target)
    return target and target.IsForbidden and target:IsForbidden() or false
end

local function CanSkin(target)
    return target and not IsForbidden(target)
end

local function GetFrame()
    return _G.BarberShopFrame
end

local function GetCustomizeFrame()
    return _G.CharCustomizeFrame
end

local function QueueApply()
    if applyPending then return end
    applyPending = true
    C_Timer.After(0, function()
        applyPending = false
        BarberShopSkin:Apply()
    end)
end

local function GetChildren(owner, visibleOnly)
    local targets = {}
    if not owner or not owner.GetChildren then return targets end

    for _, child in ipairs({ owner:GetChildren() }) do
        if CanSkin(child) and (not visibleOnly or IsVisible(child)) then
            targets[#targets + 1] = child
        end
    end
    return targets
end

local function GetButtonIcon(button)
    if not button then return nil end
    return button.Icon or button.icon
        or (button.GetName and button:GetName()
            and _G[button:GetName() .. "Icon"])
end

local function GetSelectableIconDecorations(button)
    if not button then return nil end
    return {
        button.NormalTexture,
        button.PushedTexture,
        button.HighlightTexture,
        button.CheckedTexture,
        button.DisabledOverlay,
        button.Ring,
        button.BlackBG,
    }
end

local function GetSelected(button)
    return button and button.GetChecked
        and button:GetChecked() == true or false
end

local function GetHovered(button)
    return button and button.IsMouseOver
        and button:IsMouseOver() or false
end

local function StyleSelectableIcon(button, elementID)
    if not CanSkin(button) then return false end
    local icon = GetButtonIcon(button)
    if not icon then return false end

    return NSkin:SkinTypedElement("ICON", {
        id = elementID,
        appearanceWindowID = IDs.Scope,
        target = button,
        texture = icon,
        borderOwner = button,
        nativeDecorationRegions = GetSelectableIconDecorations(button),
        getSelected = GetSelected,
        getHovered = GetHovered,
    })
end

local function RegisterHomogeneousGroup(definition)
    if registeredGroups[definition.id] then
        return true
    end

    registeredGroups[definition.id] =
        NSkin:RegisterSkinningElement(definition.id, {
            module = "BarberShop",
            appearanceWindowID = IDs.Scope,
            label = definition.label,
            kind = definition.kind,
            window = definition.window,
            target = definition.target,
            priority = definition.priority,
            draggable = false,
            appearanceStyles = definition.appearanceStyles,
            appearanceTypeIDs = definition.appearanceTypeIDs,
            highlightRegions = definition.highlightRegions,
            pixelBorderTargets = definition.pixelBorderTargets,
            refreshAppearance = definition.refreshAppearance,
            refreshLayout = definition.refreshLayout
                or definition.refreshAppearance,
            isEditable = definition.isEditable,
        }) == true

    return registeredGroups[definition.id]
end

local function RefreshSelectableIconGroup(
    window, owner, id, label, priority)
    if not owner then return false end

    local function GetTargets(visibleOnly)
        local result = {}
        for _, button in ipairs(GetChildren(owner, visibleOnly)) do
            if GetButtonIcon(button) then
                result[#result + 1] = button
            end
        end
        return result
    end

    local function Refresh()
        local applied = false
        for _, button in ipairs(GetTargets(false)) do
            applied = StyleSelectableIcon(button, id) or applied
        end
        return applied
    end

    RegisterHomogeneousGroup({
        id = id,
        label = label,
        kind = "ICON",
        window = window,
        target = owner,
        priority = priority,
        highlightRegions = function()
            return GetTargets(true)
        end,
        pixelBorderTargets = function()
            return GetTargets(true)
        end,
        refreshAppearance = Refresh,
        isEditable = function()
            return IsVisible(window) and IsVisible(owner)
                and #GetTargets(true) > 0
        end,
    })

    local applied = Refresh()
    if registeredGroups[id] then
        NSkin:NotifySkinningElementBoundsChanged(id)
    end
    return applied or registeredGroups[id]
end

function BarberShopSkin:ApplyWindowRegistration(frame)
    if not frame then return false end

    if not NSkin:GetSkinningElement(IDs.Window) then
        NSkin:RegisterSkinningElement(IDs.Window, {
            module = "BarberShop",
            appearanceWindowID = IDs.Scope,
            label = "Barber Shop window",
            kind = "WINDOW",
            window = frame,
            target = frame,
            priority = 0,
            draggable = false,
            refreshAppearance = function()
                return true
            end,
            refreshLayout = function()
                NSkin:NotifySkinningElementBoundsChanged(IDs.Window)
                return true
            end,
            isEditable = function()
                return IsVisible(frame)
            end,
        })
    end

    return true
end

function BarberShopSkin:ApplyMainButtons(frame)
    if not frame then return false end

    local applied = false
    local definitions = {
        {
            id = IDs.Cancel,
            label = "Cancel button",
            target = frame.CancelButton,
            kind = "BUTTON",
            priority = 20,
        },
        {
            id = IDs.Reset,
            label = "Reset button",
            target = frame.ResetButton,
            kind = "BUTTON",
            priority = 21,
        },
        {
            id = IDs.Accept,
            label = "Accept button",
            target = frame.AcceptButton,
            kind = "ACTION_BUTTON",
            priority = 22,
        },
    }

    for _, definition in ipairs(definitions) do
        local button = definition.target
        if CanSkin(button) then
            local element = NSkin:RegisterTypedElement(definition.kind, {
                id = definition.id,
                module = "BarberShop",
                appearanceWindowID = IDs.Scope,
                label = definition.label,
                window = frame,
                target = button,
                priority = definition.priority,
                highlightRegions = { button },
                isEditable = function()
                    return IsVisible(frame) and IsVisible(button)
                end,
            })

            if element then
                NSkin:RefreshTypedElementAppearance(element)
                applied = true
            end
        end
    end

    return applied
end

function BarberShopSkin:ApplyBodyTypes(frame)
    return RefreshSelectableIconGroup(
        frame, frame and frame.BodyTypes, IDs.BodyTypes,
        "Body type buttons", 30)
end

function BarberShopSkin:ApplyAlteredForms(frame, customize)
    if not customize then return false end

    local applied = RefreshSelectableIconGroup(
        frame, customize.AlteredForms, IDs.AlteredForms,
        "Altered form buttons", 31)

    local dropdown = customize.FormsDropdown
    if CanSkin(dropdown) then
        local element = NSkin:RegisterTypedElement("DROPDOWN", {
            id = IDs.FormsDropdown,
            module = "BarberShop",
            appearanceWindowID = IDs.Scope,
            label = "Altered forms dropdown",
            window = frame,
            target = dropdown,
            priority = 32,
            highlightRegions = { dropdown },
            isEditable = function()
                return IsVisible(frame) and IsVisible(dropdown)
            end,
        })

        if element then
            NSkin:RefreshTypedElementAppearance(element)
            applied = true
        end
    end

    return applied
end

function BarberShopSkin:ApplyCategories(frame, customize)
    return RefreshSelectableIconGroup(
        frame, customize and customize.Categories, IDs.Categories,
        "Customization category buttons", 40)
end

function BarberShopSkin:ApplyRandomize(frame, customize)
    local button = customize and customize.RandomizeAppearanceButton
    if not CanSkin(button) then return false end

    local element = NSkin:RegisterTypedElement("BUTTON", {
        id = IDs.Randomize,
        module = "BarberShop",
        appearanceWindowID = IDs.Scope,
        label = "Randomize appearance",
        window = frame,
        target = button,
        priority = 41,
        preserveTexture = true,
        highlightRegions = { button },
        isEditable = function()
            return IsVisible(frame) and IsVisible(button)
        end,
    })

    if element then
        NSkin:RefreshTypedElementAppearance(element)
        return true
    end

    return false
end

local function GetCameraButtons(customize, visibleOnly)
    local smallButtons = customize and customize.SmallButtons
    if not smallButtons then return {} end

    local targets = {}
    for _, button in ipairs(smallButtons.ControlButtons or {}) do
        if CanSkin(button) and (not visibleOnly or IsVisible(button)) then
            targets[#targets + 1] = button
        end
    end
    return targets
end

local function StyleCameraButton(button)
    if not CanSkin(button) then return false end

    local kind = NSkin:GetSharedElementType("CAMERA_CONTROL")
        and "CAMERA_CONTROL" or "BUTTON"

    return NSkin:SkinTypedElement(kind, {
        id = IDs.CameraControls,
        appearanceWindowID = IDs.Scope,
        target = button,
        preserveTexture = true,
        skinOptions = {
            preserveTexture = true,
        },
    })
end

function BarberShopSkin:ApplyCameraControls(frame, customize)
    local smallButtons = customize and customize.SmallButtons
    if not smallButtons then return false end

    local function Refresh()
        local applied = false
        for _, button in ipairs(GetCameraButtons(customize, false)) do
            applied = StyleCameraButton(button) or applied
        end
        return applied
    end

    local kind = NSkin:GetSharedElementType("CAMERA_CONTROL")
        and "CAMERA_CONTROL" or "BUTTON"

    RegisterHomogeneousGroup({
        id = IDs.CameraControls,
        label = "Camera controls",
        kind = kind,
        window = frame,
        target = smallButtons,
        priority = 42,
        highlightRegions = function()
            return GetCameraButtons(customize, true)
        end,
        pixelBorderTargets = function()
            return GetCameraButtons(customize, true)
        end,
        refreshAppearance = Refresh,
        isEditable = function()
            return IsVisible(frame) and IsVisible(smallButtons)
                and #GetCameraButtons(customize, true) > 0
        end,
    })

    local applied = Refresh()
    if registeredGroups[IDs.CameraControls] then
        NSkin:NotifySkinningElementBoundsChanged(IDs.CameraControls)
    end
    return applied or registeredGroups[IDs.CameraControls]
end

local function GetOptionFrames(customize)
    local result = {}
    local seen = {}

    local function AddFromPool(pool)
        if not pool or type(pool.EnumerateActive) ~= "function" then return end
        for option in pool:EnumerateActive() do
            if option and not seen[option] and CanSkin(option) then
                seen[option] = true
                result[#result + 1] = option
            end
        end
    end

    AddFromPool(customize and customize.dropdownPool)
    AddFromPool(customize and customize.sliderPool)

    local checkPool = customize and customize.pools
        and customize.pools.GetPool
        and customize.pools:GetPool("CustomizationOptionCheckButtonTemplate")
    AddFromPool(checkPool)

    return result
end

local function GetOptionTargets(customize, kind, visibleOnly)
    local targets = {}

    for _, option in ipairs(GetOptionFrames(customize)) do
        local target
        if kind == "DROPDOWN" then
            target = option.Dropdown
        elseif kind == "SLIDER" then
            target = option.Slider
        elseif kind == "CHECKBOX" then
            target = option.Button
        elseif kind == "TEXT" then
            target = option.Label
        end

        if target and CanSkin(target)
            and (not visibleOnly or IsVisible(target))
        then
            targets[#targets + 1] = target
        end
    end

    return targets
end

local function GetOptionStepperTargets(customize, visibleOnly)
    local targets = {}

    for _, option in ipairs(GetOptionFrames(customize)) do
        for _, button in ipairs({
            option.DecrementButton,
            option.IncrementButton,
        }) do
            if CanSkin(button)
                and (not visibleOnly or IsVisible(button))
            then
                targets[#targets + 1] = button
            end
        end
    end

    return targets
end

local function StyleOptionTargets(customize, id, kind)
    local applied = false

    for _, target in ipairs(GetOptionTargets(customize, kind, false)) do
        local definition = {
            id = id,
            appearanceWindowID = IDs.Scope,
            target = target,
        }

        if kind == "CHECKBOX" then
            local parent = target.GetParent and target:GetParent()
            definition.text = parent and parent.Label
            definition.getChecked = function(button)
                return button.GetChecked and button:GetChecked() == true
            end
        end

        applied = NSkin:SkinTypedElement(kind, definition) or applied
    end

    return applied
end

function BarberShopSkin:ApplyOptions(frame, customize)
    if not customize or not customize.Options then return false end

    local applied = false
    local groups = {
        {
            id = IDs.Options.Dropdowns,
            label = "Customization dropdowns",
            kind = "DROPDOWN",
            priority = 50,
        },
        {
            id = IDs.Options.Sliders,
            label = "Customization sliders",
            kind = "SLIDER",
            priority = 51,
        },
        {
            id = IDs.Options.Checkboxes,
            label = "Customization checkboxes",
            kind = "CHECKBOX",
            priority = 52,
        },
    }

    for _, group in ipairs(groups) do
        local function Refresh()
            return StyleOptionTargets(customize, group.id, group.kind)
        end

        RegisterHomogeneousGroup({
            id = group.id,
            label = group.label,
            kind = group.kind,
            window = frame,
            target = customize.Options,
            priority = group.priority,
            highlightRegions = function()
                return GetOptionTargets(customize, group.kind, true)
            end,
            pixelBorderTargets = function()
                return GetOptionTargets(customize, group.kind, true)
            end,
            refreshAppearance = Refresh,
            isEditable = function()
                return IsVisible(frame) and IsVisible(customize.Options)
                    and #GetOptionTargets(customize, group.kind, true) > 0
            end,
        })

        applied = Refresh() or applied
        if registeredGroups[group.id] then
            NSkin:NotifySkinningElementBoundsChanged(group.id)
        end
    end

    local function RefreshLabels()
        local style = NSkin:GetAppearanceStyle(
            "text", IDs.Scope, IDs.Options.Labels)
        local changed = false
        for _, target in ipairs(GetOptionTargets(customize, "TEXT", false)) do
            changed = NSkin:SkinText(target, style) or changed
        end
        return changed
    end

    RegisterHomogeneousGroup({
        id = IDs.Options.Labels,
        label = "Customization option labels",
        kind = "TEXT",
        window = frame,
        target = customize.Options,
        priority = 53,
        highlightRegions = function()
            return GetOptionTargets(customize, "TEXT", true)
        end,
        refreshAppearance = RefreshLabels,
        isEditable = function()
            return IsVisible(frame) and IsVisible(customize.Options)
                and #GetOptionTargets(customize, "TEXT", true) > 0
        end,
    })

    applied = RefreshLabels() or applied

    local function RefreshSteppers()
        local changed = false
        for _, button in ipairs(GetOptionStepperTargets(customize, false)) do
            changed = NSkin:SkinTypedElement("BUTTON", {
                id = IDs.Options.Steppers,
                appearanceWindowID = IDs.Scope,
                target = button,
                preserveTexture = true,
                skinOptions = {
                    preserveTexture = true,
                },
            }) or changed
        end
        return changed
    end

    RegisterHomogeneousGroup({
        id = IDs.Options.Steppers,
        label = "Customization option steppers",
        kind = "BUTTON",
        window = frame,
        target = customize.Options,
        priority = 54,
        highlightRegions = function()
            return GetOptionStepperTargets(customize, true)
        end,
        pixelBorderTargets = function()
            return GetOptionStepperTargets(customize, true)
        end,
        refreshAppearance = RefreshSteppers,
        isEditable = function()
            return IsVisible(frame) and IsVisible(customize.Options)
                and #GetOptionStepperTargets(customize, true) > 0
        end,
    })

    applied = RefreshSteppers() or applied

    for _, id in ipairs({
        IDs.Options.Labels,
        IDs.Options.Steppers,
    }) do
        if registeredGroups[id] then
            NSkin:NotifySkinningElementBoundsChanged(id)
        end
    end

    return applied
end

function BarberShopSkin:HookLifecycle(frame, customize)
    if lifecycleHooked then return end

    if frame and frame.HookScript then
        frame:HookScript("OnShow", QueueApply)
    end

    if customize and customize.HookScript then
        customize:HookScript("OnShow", QueueApply)
    end

    if _G.hooksecurefunc then
        for _, method in ipairs({
            "UpdateSex",
            "UpdateCharCustomizationFrame",
            "UpdateButtons",
        }) do
            if frame and type(frame[method]) == "function" then
                pcall(_G.hooksecurefunc, frame, method, QueueApply)
            end
        end

        for _, method in ipairs({
            "UpdateOptionButtons",
            "UpdateAlteredForms",
            "UpdateAlteredFormButtons",
            "UpdateAlteredFormsDropdown",
            "UpdateCategoriesContainer",
            "UpdateOptionsContainer",
            "UpdateZoomButtonStates",
        }) do
            if customize and type(customize[method]) == "function" then
                pcall(_G.hooksecurefunc, customize, method, QueueApply)
            end
        end
    end

    lifecycleHooked = true
end

function BarberShopSkin:Apply()
    local frame = GetFrame()
    local customize = GetCustomizeFrame()
    if not frame or not customize then return false end

    self:ApplyWindowRegistration(frame)
    self:ApplyMainButtons(frame)
    self:ApplyBodyTypes(frame)
    self:ApplyAlteredForms(frame, customize)
    self:ApplyCategories(frame, customize)
    self:ApplyRandomize(frame, customize)
    self:ApplyCameraControls(frame, customize)
    self:ApplyOptions(frame, customize)

    return true
end

function BarberShopSkin:Initialize()
    local frame = GetFrame()
    local customize = GetCustomizeFrame()
    if not frame or not customize then return false end

    self:HookLifecycle(frame, customize)

    initialized = true
    local applied = self:Apply()

    if IsVisible(frame) then
        QueueApply()
    end

    return applied
end

function BarberShopSkin:RefreshAppearance()
    if initialized then
        self:Apply()
    end
end

NSkin:RegisterWindowSkin({
    module = "BarberShop",
    addon = "Blizzard_BarbershopUI",
    apply = function()
        return BarberShopSkin:Initialize()
    end,
})
