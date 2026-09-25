-- Run from the repository root with Lua 5.4 (no WoW client required).
local profile = {}
local function eq(actual, expected, message)
    assert(actual == expected, message .. ": " .. tostring(actual))
end

_G.wipe = function(target)
    for key in pairs(target) do target[key] = nil end
end
_G.unpack = table.unpack

local N = { modules = {}, baseAppearance = {
    typography = { font = "Fonts\\FRIZQT__.TTF", size = 12, outline = "" },
    accent = { enabled = false, color = { 0.2, 0.6, 1, 1 } },
    button = {
        background = { 0.1, 0.1, 0.1, 1 }, border = { 1, 1, 1, 1 },
        hoverAlpha = 0.1,
    },
    icon = { border = { 0, 0, 0, 1 } },
} }
function N:RegisterEvent() end
function N:GetProfile() return profile end
assert(loadfile("Components/NSkin_ComponentsCore.lua"))("NSkin", N)
function N:IsModuleEnabled() return true end

assert(N:RegisterAppearanceScope("Alpha", {}))
local windowReads = 0
local alphaOverrides = { button = { background = { 0.2, 0.2, 0.2, 1 } } }
profile.appearanceOverrides = {
    windows = setmetatable({}, { __index = function(_, key)
        windowReads = windowReads + 1
        return key == "Alpha" and alphaOverrides or nil
    end }),
}

local first = N:GetAppearanceStyle("button", "Alpha")
eq(windowReads, 1, "first style resolution reads overrides")
local second = N:GetAppearanceStyle("button", "Alpha")
eq(windowReads, 1, "cached style skips override resolution")
assert(first ~= second, "cached styles return isolated top-level tables")
assert(first.background ~= second.background,
    "cached styles return isolated nested tables")
first.background[1] = 0.9
eq(second.background[1], 0.2, "caller mutation cannot poison cache")

alphaOverrides.button.background[1] = 0.3
N:InvalidateAppearance({ scope = "window", windowID = "Alpha" })
local windowChanged = N:GetAppearanceStyle("button", "Alpha")
eq(windowChanged.background[1], 0.3, "window revision invalidates style cache")
eq(windowReads, 2, "window invalidation resolves once")

profile.appearance = { button = { hoverAlpha = 0.25 } }
N:InvalidateAppearance({ scope = "type", style = "button" })
local typeChanged = N:GetAppearanceStyle("button", "Alpha")
eq(typeChanged.hoverAlpha, 0.25, "style revision invalidates matching cache")

local elementOverrides = { button = { background = { 0.4, 0.4, 0.4, 1 } } }
profile.appearanceOverrides.elements = { ["Alpha.Button"] = elementOverrides }
N:InvalidateAppearance({ scope = "element", elementID = "Alpha.Button" })
local elementChanged = N:GetAppearanceStyle("button", "Alpha", "Alpha.Button")
eq(elementChanged.background[1], 0.4, "element revision resolves element override")
elementOverrides.button.background[1] = 0.5
N:InvalidateAppearance({ scope = "element", elementID = "Alpha.Button" })
eq(N:GetAppearanceStyle("button", "Alpha", "Alpha.Button").background[1], 0.5,
    "element revision invalidates only the element cache")

profile.appearance.button.hoverAlpha = 0.3
N:InvalidateAppearance({ scope = "global", style = "typography" })
eq(N:GetAppearanceStyle("button", "Alpha").hoverAlpha, 0.3,
    "global generation invalidates all resolved styles")

local chain = N:GetAppearanceScopeChain("Alpha")
chain[1] = "poisoned"
eq(N:GetAppearanceScopeChain("Alpha")[1], "Alpha",
    "scope-chain callers receive isolated copies")

local refreshes = 0
local originalRefresh = N.RefreshAppearance
N.RefreshAppearance = function(self, change)
    refreshes = refreshes + 1
    return originalRefresh(self, change)
end
assert(N:SetAppearanceOverride("button.hoverAlpha", 0.4))
eq(refreshes, 1, "changed global value refreshes")
assert(not N:SetAppearanceOverride("button.hoverAlpha", 0.4))
eq(refreshes, 1, "unchanged global value skips refresh")
assert(N:ResetAppearanceOverride("button.hoverAlpha"))
eq(refreshes, 2, "existing global override reset refreshes")
assert(not N:ResetAppearanceOverride("button.hoverAlpha"))
eq(refreshes, 2, "missing global override reset skips refresh")

local api = { geometry = 0, color = 0 }
local function NewTexture()
    local texture = {}
    function texture:SetColorTexture() api.color = api.color + 1 end
    function texture:SetSnapToPixelGrid() end
    function texture:SetTexelSnappingBias() end
    function texture:ClearAllPoints() api.geometry = api.geometry + 1 end
    function texture:SetPoint() api.geometry = api.geometry + 1 end
    function texture:SetHeight() api.geometry = api.geometry + 1 end
    function texture:SetWidth() api.geometry = api.geometry + 1 end
    function texture:SetShown() end
    return texture
end
local frame = {}
function frame:CreateTexture() return NewTexture() end
function frame:IsObjectType(kind) return kind == "Frame" end
function frame:GetEffectiveScale() return 1 end
function frame:HookScript() end

local border = N:CreatePixelBorder(frame, "Pass4", 1, { 1, 1, 1, 1 })
local geometry = api.geometry
local colorCalls = api.color
assert(not N:SetPixelBorderSize(border, 1))
eq(api.geometry, geometry, "unchanged border size skips geometry")
assert(N:SetPixelBorderSize(border, 2))
assert(api.geometry > geometry, "changed border size applies geometry")
geometry = api.geometry
assert(N:SetPixelBorderPadding(border, 0))
assert(api.geometry > geometry, "first explicit padding applies geometry")
geometry = api.geometry
assert(not N:SetPixelBorderPadding(border, 0))
eq(api.geometry, geometry, "unchanged border padding skips geometry")
assert(not N:SetPixelBorderColor(border, 1, 1, 1, 1))
eq(api.color, colorCalls, "unchanged border color skips API calls")
assert(N:SetPixelBorderColor(border, 0.5, 0.5, 0.5, 1))
eq(api.color, colorCalls + 4, "changed border color updates each edge once")

local sliderScripts = {}
local function NewSliderTexture()
    local texture = NewTexture()
    function texture:SetPoint() end
    function texture:SetBlendMode() end
    function texture:SetSize() end
    function texture:SetTexture() end
    return texture
end
local slider = { thumb = NewSliderTexture() }
function slider:SetSize(width) self.width = width end
function slider:SetOrientation() end
function slider:SetMinMaxValues() end
function slider:SetValueStep() end
function slider:SetObeyStepOnDrag() end
function slider:CreateTexture() return NewSliderTexture() end
function slider:SetThumbTexture() end
function slider:GetThumbTexture() return self.thumb end
function slider:GetWidth() return self.width end
function slider:GetValue() return 0 end
function slider:SetScript(script, callback) sliderScripts[script] = callback end
_G.CreateFrame = function() return slider end
local liveSamples = 0
N:CreateOptionsSlider({}, {
    width = 100,
    onValueChanged = function() liveSamples = liveSamples + 1 end,
})
sliderScripts.OnValueChanged(slider, 25)
sliderScripts.OnValueChanged(slider, 25)
eq(liveSamples, 2, "OnValueChanged remains fully live without throttling")

local liveChange
N.RefreshAppearance = function(_, change) liveChange = change end
assert(N:RunWithLiveInspectorAppearanceChange("Alpha.Button", function()
    return N:SetElementAppearanceOverride(
        "Alpha.Button", "Alpha", "button.hoverAlpha", 0.55)
end))
eq(liveChange.origin, "activeInspectorLive",
    "live inspector writes carry a precise origin")
eq(N:ShouldRefreshSkinningModeInspector(liveChange, "Alpha.Button"), false,
    "selected live appearance change preserves active inspector")
liveChange.requirement = "layout"
eq(N:ShouldRefreshSkinningModeInspector(liveChange, "Alpha.Button"), false,
    "selected live layout change preserves active inspector")
liveChange.requirement = "structural"
eq(N:ShouldRefreshSkinningModeInspector(liveChange, "Alpha.Button"), true,
    "structural changes still rebuild active inspector")
liveChange.requirement = "appearance"
eq(N:ShouldRefreshSkinningModeInspector(liveChange, "Alpha.Other"), true,
    "selection mismatch still permits inspector refresh")
liveChange.origin = nil
eq(N:ShouldRefreshSkinningModeInspector(liveChange, "Alpha.Button"), true,
    "external element changes still refresh active inspector")

local failed = pcall(function()
    N:RunWithLiveInspectorAppearanceChange("Alpha.Button", function()
        error("expected")
    end)
end)
eq(failed, false, "live inspector guard propagates setter errors")
eq(N._liveInspectorAppearanceElementID, nil,
    "live inspector guard restores origin after errors")

if io and io.open then
    local optionsFile = assert(io.open(
        "Options/Components/NSkin_ComponentOptionsCore.lua", "r"))
    local optionsSource = optionsFile:read("*a")
    optionsFile:close()
    assert(not optionsSource:find("onValueCommitted%s*="),
        "Options sliders must not wait for commit or mouse release")
    local _, handlerCount = optionsSource:gsub("onValueChanged%s*=", "")
    assert(handlerCount >= 3, "Options controls retain live slider handlers")
    local _, liveCommitCount = optionsSource:gsub(
        "CommitValues%(view, current, values, true%)", "")
    assert(liveCommitCount >= 3,
        "all slider families preserve the active inspector during live writes")
    assert(optionsSource:find("view ~= excludedView", 1, true),
        "live inspector view retains its local slider and value-label state")
end

print("Optimization Pass 4 regression tests passed")
