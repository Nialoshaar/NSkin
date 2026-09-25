-- Run from the repository root with Lua 5.4 (no WoW client required).
local profile, counts, deferred = {}, {}, {}
local function count(key) counts[key] = (counts[key] or 0) + 1 end
local function clear() for key in pairs(counts) do counts[key] = nil end end
local function eq(actual, expected, message)
    assert(actual == expected, message .. ": " .. tostring(actual))
end

_G.wipe = function(t) for key in pairs(t) do t[key] = nil end end
_G.unpack = table.unpack
_G.C_Timer = { After = function(_, callback) deferred[#deferred + 1] = callback end }
_G.GetPhysicalScreenSize = function() return 1024, 768 end

for _, path in ipairs({
    "Components/NSkin_ComponentsCore.lua",
    "Components/NSkin_ComponentsInputs.lua",
    "Components/NSkin_ComponentsNavigation.lua",
    "NSkin_DockedWindow.lua",
    "NSkin_Commands.lua",
    "Debug/NSkin_AppearanceDebug.lua",
}) do
    assert(loadfile(path), "syntax check failed: " .. path)
end

local N = { modules = {}, baseAppearance = {
    button = { width = 0, borderSize = 1, background = { 0, 0, 0, 1 } },
    icon = { width = 0, height = 0, zoom = 0, crop = 1, border = { 1, 1, 1, 1 } },
    tab = { width = 0, spacing = 0 },
} }
function N:RegisterEvent() end
function N:GetProfile() return profile end
assert(loadfile("Components/NSkin_ComponentsCore.lua"))("NSkin", N)
assert(loadfile("Debug/NSkin_AppearanceDebug.lua"))("NSkin", N)
function N:IsModuleEnabled() return true end
function N:GetAppearanceBorderColor() return { 1, 1, 1, 1 } end
function N:SkinActionButton(target, options) count("skin"); target.style = options.style end
function N:SkinIcon(target, options) count("generatedIcon"); target.options = options end
function N:CreateEditorOptionsPreset() count("preset"); return {} end
function N:RegisterMovableElement(definition)
    count("setup")
    definition.applyPlacement = function() count("placement"); return true end
    self:RegisterSkinningElement(definition.id, definition)
    return true
end
function N:GetSavedMovableElementPlacement() return { x = 0 } end
function N:IsSkinningElementEditable() return true end
function N:NotifySkinningElementBoundsChanged() count("bounds") end
function N:RefreshOptionsAppearance() count("options") end
function N:RefreshSkinningModeAppearance() count("inspector") end
function N:RefreshRegisteredTabGroups() count("tabs") end
N.modules.Pass2 = { name = "Pass2", RefreshAppearance = function() count("module") end }
N:RegisterAppearanceScope("Pass2", {})

local target, window = {}, {}
local function definition()
    return { id = "Pass2.Button", module = "Pass2", target = target,
        window = window, appearanceWindowID = "Pass2" }
end
local element = N:RegisterActionButton(definition())
clear()
for _ = 1, 10 do eq(N:RegisterActionButton(definition()), element, "canonical reuse") end
eq(counts.skin, nil, "idempotent registration skin")
eq(counts.setup, nil, "idempotent registration setup")
eq(counts.preset, nil, "idempotent registration preset")

assert(N:SetElementAppearanceOverride(element.id, "Pass2", "button.borderSize", 2))
eq(counts.skin, 1, "targeted appearance skin")
eq(counts.placement, nil, "targeted appearance placement")
eq(counts.bounds, nil, "targeted appearance bounds")
clear()
assert(N:SetElementAppearanceOverride(element.id, "Pass2", "button.width", 40))
eq(counts.skin, 1, "targeted layout skin")
eq(counts.placement, 1, "targeted layout placement")
eq(counts.bounds, 1, "targeted layout bounds")

local captured
local refresh = N.RefreshAppearance
N.RefreshAppearance = function(self, change) captured = change; return refresh(self, change) end
clear()
assert(N:ResetElementAppearanceOverride(element.id, "button.borderSize"))
eq(captured.scope, "element", "reset scope")
eq(captured.elementID, element.id, "reset element")
eq(captured.windowID, "Pass2", "reset window")
eq(captured.style, "button", "reset style")
eq(captured.path, "borderSize", "reset path")
assert(N:ResetElementAppearanceOverride(element.id))
local sawWidth
for _, change in ipairs(captured.changes) do
    if change.style == "button" and change.path == "width" then sawWidth = true end
end
assert(sawWidth, "whole reset preserves leaf paths")

local groupAppearance, groupLayout = 0, 0
N:RegisterSkinningElement("Pass2.Tabs", {
    id = "Pass2.Tabs", module = "Pass2", kind = "TAB_GROUP",
    appearanceWindowID = "Pass2", target = {}, window = window,
    refreshAppearance = function() groupAppearance = groupAppearance + 1; return true end,
    refreshLayout = function() groupLayout = groupLayout + 1; return true end,
})
N:RefreshAppearance({ scope = "element", elementID = "Pass2.Tabs",
    windowID = "Pass2", style = "tab", path = "borderSize" })
eq(groupAppearance, 1, "group appearance contract")
N:RefreshAppearance({ scope = "element", elementID = "Pass2.Tabs",
    windowID = "Pass2", style = "tab", path = "spacing" })
eq(groupLayout, 1, "group layout contract")

local function texture()
    return { SetColorTexture = function() end, SetSnapToPixelGrid = function() end,
        SetTexelSnappingBias = function() end, ClearAllPoints = function() count("edgeSnap") end,
        SetPoint = function() end, SetHeight = function() end, SetWidth = function() end }
end
local owner = { CreateTexture = function() return texture() end,
    IsObjectType = function(_, kind) return kind == "Frame" end,
    HookScript = function() end, SetScale = function() end, GetEffectiveScale = function() return 1 end }
N:CreatePixelBorder(owner, "one", 1)
N:CreatePixelBorder(owner, "two", 1)
local otherOwner = { CreateTexture = function() return texture() end,
    IsObjectType = owner.IsObjectType, HookScript = owner.HookScript,
    SetScale = owner.SetScale, GetEffectiveScale = owner.GetEffectiveScale }
N:CreatePixelBorder(otherOwner, "other", 1)
clear(); deferred = {}
assert(N:ResnapPixelBordersForTarget(owner))
assert(N:ResnapPixelBordersForTarget(owner))
eq(#deferred, 1, "owner resnaps coalesce")
deferred[1]()
eq(counts.edgeSnap, 8, "owner resnaps exclude unrelated borders")

clear()
N:SkinTypedElement("ICON", { target = {}, appearanceWindowID = "Pass2" })
N:SkinTypedElement("ICON", { target = {}, appearanceWindowID = "Pass2" })
eq(counts.generatedIcon, 2, "generated targets share typed appearance")

N:ResetAppearanceRefreshDebugCounters()
N:RefreshAppearance({ scope = "element", elementID = "missing" })
N:RefreshAppearance({ scope = "global", style = "button", path = "borderSize" })
local debug = N:GetAppearanceRefreshDebugCounters()
eq(debug.total, 2, "fallback total")
eq(debug.reasons.unresolved_element, 1, "unresolved fallback")
eq(debug.reasons.global_change, 1, "global fallback")
print("Optimization Pass 2 regression tests passed")
