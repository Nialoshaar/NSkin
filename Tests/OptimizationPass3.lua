-- Run from the repository root with Lua 5.4 (no WoW client required).
local profile, counts = {}, {}
local function count(key) counts[key] = (counts[key] or 0) + 1 end
local function clear() for key in pairs(counts) do counts[key] = nil end end
local function eq(actual, expected, message)
    assert(actual == expected, message .. ": " .. tostring(actual))
end

_G.wipe = function(t) for key in pairs(t) do t[key] = nil end end
local N = { modules = {}, baseAppearance = {
    typography = { font = "Fonts\\FRIZQT__.TTF", outline = "" },
    button = { background = { 0, 0, 0, 1 }, border = { 1, 1, 1, 1 },
        hoverAlpha = 0.1 },
    icon = { border = { 0, 0, 0, 1 }, width = 0, height = 0,
        zoom = 0.06, crop = 1, shape = "square" },
} }
function N:RegisterEvent() end
function N:GetProfile() return profile end
assert(loadfile("Components/NSkin_ComponentsCore.lua"))("NSkin", N)
function N:IsModuleEnabled() return true end
function N:GetAppearanceBorderColor() return { 1, 1, 1, 1 } end
function N:SkinActionButton(target, options)
    count("buttonSkin")
    target.style, target.options = options.style, options
end
function N:SkinCheckButton(target, options)
    count("checkboxSkin")
    target.style, target.options = options.style, options
end
function N:SkinIcon(target, options) count("iconSkin"); target.options = options end
function N:CreateEditorOptionsPreset() count("preset"); return {} end
function N:RegisterMovableElement(definition)
    count("setup")
    definition.applyPlacement = definition.applyPlacement or function() return true end
    self:RegisterSkinningElement(definition.id, definition)
    return true
end
function N:GetSavedMovableElementPlacement() return nil end
function N:IsSkinningElementEditable() return true end
function N:NotifySkinningElementBoundsChanged() count("bounds") end
function N:RefreshOptionsAppearance() count("options") end
function N:RefreshSkinningModeAppearance() count("skinningMode") end
function N:RefreshRegisteredTabGroups() count("tabs") end
N.ResnapAllPixelBorders = function() count("globalResnap") end

N.modules.Alpha = { name = "Alpha", RefreshAppearance = function() count("alpha") end }
N.modules.Beta = { name = "Beta", RefreshAppearance = function() count("beta") end }
assert(N:RegisterAppearanceScope("Alpha", {}))
assert(N:RegisterAppearanceScope("Alpha.Child", { parent = "Alpha" }))
assert(N:RegisterAppearanceScope("Beta", {}))

local windowAlpha, windowBeta = {}, {}
local alphaTarget, betaTarget, checkboxTarget, iconTarget = {}, {}, {}, {}
local alpha = N:RegisterActionButton({ id = "Alpha.Button", module = "Alpha",
    appearanceWindowID = "Alpha.Child", window = windowAlpha, target = alphaTarget })
local beta = N:RegisterActionButton({ id = "Beta.Button", module = "Beta",
    appearanceWindowID = "Beta", window = windowBeta, target = betaTarget })
N:RegisterCheckbox({ id = "Beta.Checkbox", module = "Beta",
    appearanceWindowID = "Beta", window = windowBeta, target = checkboxTarget })
N:RegisterIcon({ id = "Beta.Icon", module = "Beta", appearanceWindowID = "Beta",
    window = windowBeta, target = iconTarget })

clear()
assert(N:SetWindowAppearanceOverride("Alpha", "button.border", { 0.2, 0.3, 0.4, 1 }))
eq(counts.alpha, 1, "window refresh owning module")
eq(counts.beta, nil, "window skips unrelated module")
eq(counts.options, nil, "window skips options refresh")
eq(counts.tabs, nil, "window skips global tabs")
eq(counts.globalResnap, nil, "window skips global resnap")

clear()
assert(N:SetAppearanceOverride("button.hoverAlpha", 0.25))
eq(counts.buttonSkin, 2, "type refresh matching buttons")
eq(counts.checkboxSkin, 1, "style refresh matching checkbox")
eq(counts.iconSkin, nil, "type refresh skips nonmatching icons")
eq(counts.alpha, nil, "type refresh skips module refresh")
eq(counts.beta, nil, "type refresh skips unrelated module refresh")
eq(counts.options, 1, "type refresh updates options appearance")
eq(counts.globalResnap, nil, "type refresh skips global resnap")

clear()
N:RefreshAppearance({ scope = "type", typeID = "ACTION_BUTTON" })
eq(counts.buttonSkin, 2, "exact type refresh matching action buttons")
eq(counts.checkboxSkin, nil, "exact type refresh skips same-style checkbox")
eq(counts.iconSkin, nil, "exact type refresh skips unrelated icon")
eq(counts.globalResnap, nil, "exact type refresh skips global resnap")

clear()
assert(N:SetAppearanceOverride("typography.font", "Fonts\\ARIALN.TTF"))
eq(counts.alpha, 1, "global refresh alpha module")
eq(counts.beta, 1, "global refresh beta module")
eq(counts.options, 1, "global refresh options")
eq(counts.tabs, 1, "global refresh tabs")
eq(counts.globalResnap, 1, "global refresh global resnap")

local compareTarget = {}
local function compareDefinition(marker, label)
    return { id = "Alpha.Compare", module = "Alpha",
        appearanceWindowID = "Alpha", window = windowAlpha, target = compareTarget,
        label = label, skinOptions = { nested = { marker = marker } } }
end
clear()
local compared = N:RegisterActionButton(compareDefinition(1, "first"))
clear()
eq(N:RegisterActionButton(compareDefinition(1, "renamed")), compared,
    "comparison preserves canonical identity")
eq(counts.buttonSkin, nil, "equal skin inputs skip skin")
eq(compared.label, "renamed", "non-skin metadata still updates")
eq(N:RegisterActionButton(compareDefinition(2, "renamed")), compared,
    "changed skin input preserves identity")
eq(counts.buttonSkin, 1, "changed nested skin input reapplies skin")
eq(alpha.id, "Alpha.Button", "alpha registration remains canonical")
eq(beta.id, "Beta.Button", "beta registration remains canonical")
print("Optimization Pass 3 regression tests passed")
