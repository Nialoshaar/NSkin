-- Run from the repository root with Lua 5.4 (no WoW client required).
-- Exercises routing/registration contracts; client rendering is tested separately.
local profile, counts = {}, {}
local function count(key) counts[key] = (counts[key] or 0) + 1 end
local function clear() for key in pairs(counts) do counts[key] = nil end end
local function eq(actual, expected, message)
    assert(actual == expected, message .. ": " .. tostring(actual))
end
_G.wipe = function(t) for key in pairs(t) do t[key] = nil end end
local N = { modules = {}, baseAppearance = { button = {
    width = 0, borderSize = 1, background = { 0, 0, 0, 1 },
} } }
function N:RegisterEvent() end
function N:GetProfile() return profile end
assert(loadfile("Components/NSkin_ComponentsCore.lua"))("NSkin", N)
function N:IsModuleEnabled() return true end
function N:GetAppearanceBorderColor() return { 1, 1, 1, 1 } end
function N:SkinActionButton(target, options)
    count("skin")
    target.style = options.style
    target.options = options
end
function N:CreateEditorOptionsPreset() count("preset"); return {} end
function N:RegisterMovableElement(definition)
    count("setup")
    definition.applyPlacement = function() count("placement") end
    definition.resetPlacement = function() end
    self:RegisterSkinningElement(definition.id, definition)
    return true
end
function N:GetSavedMovableElementPlacement() return { x = 0 } end
function N:IsSkinningElementEditable() return true end
function N:RefreshOptionsAppearance() count("options") end
function N:RefreshSkinningModeAppearance() count("inspector") end
function N:RefreshRegisteredTabGroups() count("tabs") end
N.modules.Collections = { name = "Collections", RefreshAppearance = function() count("module") end }
N:RegisterAppearanceScope("Collections", {})
local target, window = {}, {}
local function definition(options)
    return { id = "Collections.Test", module = "Collections", target = target,
        window = window, appearanceWindowID = "Collections", skinOptions = options }
end
local element = N:RegisterActionButton(definition({ marker = 1 }))
local editor, reset = element.editorOptions, element.resetPlacement
eq(counts.setup, 1, "initial setup")
eq(counts.preset, 1, "initial preset")
clear()
for _ = 1, 10 do
    eq(N:RegisterActionButton(definition({ marker = 2 })), element, "canonical identity")
end
eq(counts.skin, 10, "explicit recurring skin")
eq(counts.setup, nil, "no recurring setup")
eq(counts.preset, nil, "no recurring presets")
eq(element.editorOptions, editor, "editor identity")
eq(element.resetPlacement, reset, "reset callback identity")
eq(element.skinOptions.marker, 2, "current options retained")
N:RegisterActionButton(definition())
eq(element.skinOptions, nil, "removed options cleared")
clear()
assert(N:SetElementAppearanceOverride(element.id, "Collections", "button.borderSize", 3))
eq(target.style.borderSize, 3, "element override resolved")
eq(counts.skin, 1, "one targeted component")
eq(counts.module, nil, "no module refresh")
eq(counts.tabs, nil, "no global tabs")
eq(counts.options, nil, "no options chrome")
eq(counts.placement, 1, "saved placement reapplied")
clear()
assert(N:ResetElementAppearanceOverride(element.id, "button.borderSize"))
eq(target.style.borderSize, 1, "property reset resolves inheritance")
eq(counts.module, nil, "property reset targeted")
N:SetElementAppearanceOverride(element.id, "Collections", "button.width", 42)
N:ResetElementAppearanceOverride(element.id)
eq(target.style.width, 0, "whole-element appearance reset")
local function broad(action, label)
    clear(); action()
    eq(counts.module, 1, label .. " module fallback")
    eq(counts.options, 1, label .. " options fallback")
    eq(counts.tabs, 1, label .. " tab fallback")
end
broad(function() N:RefreshAppearance() end, "compatibility")
broad(function() N:SetWindowAppearanceOverride("Collections", "button.borderSize", 2) end, "window")
broad(function() N:SetAppearanceOverride("button.borderSize", 4) end, "global")
broad(function() N:RefreshAppearance({ scope = "element", elementID = "missing" }) end, "unresolved")
element.skinAdapter = function() end
broad(function() N:RefreshAppearance({ scope = "element", elementID = element.id }) end, "custom adapter")
element.skinAdapter = nil
element.requiresStructuralRefresh = true
broad(function() N:RefreshAppearance({ scope = "element", elementID = element.id }) end, "structural element")
element.requiresStructuralRefresh = nil
N.modules.Collections.requiresStructuralRefresh = true
broad(function() N:RefreshAppearance({ scope = "element", elementID = element.id }) end, "structural module")
print("Optimization Pass 1 routing and registration tests passed")

-- Load the real Collections lifecycle with two persistent pages and a late page.
local C, registry, groups = {}, {}, {}
local callbacks = {}
local function frame()
    return { IsVisible = function() return true end, IsShown = function() return true end,
        GetLeft = function() return 10 end, GetRight = function() return 20 end,
        GetCenter = function() return 15, 15 end }
end
_G.CollectionsJournal = frame()
for _, key in ipairs({ "MountsTab", "PetsTab", "ToysTab", "HeirloomsTab", "WardrobeTab", "WarbandScenesTab" }) do
    _G.CollectionsJournal[key] = frame()
end
_G.MountJournal = { SearchBox = frame(), FilterDropdown = frame(), MountButton = frame() }
_G.PetJournal = { SearchBox = frame(), FilterDropdown = frame(), SummonButton = frame(), FindBattleButton = frame() }
local selectedTab = 1
_G.PanelTemplates_GetSelectedTab = function() return selectedTab end
_G.hooksecurefunc = function() end
_G.EventRegistry = { RegisterCallback = function(_, event, callback, owner)
    callbacks[event] = function(...) callback(owner, ...) end
end }
_G.C_Timer = { After = function(_, callback) callback() end }
function C:NewModule() self.module = {}; return self.module end
function C:RegisterAppearanceScope() end
function C:RegisterWindowSkin() end
function C:IsModuleEnabled() return true end
function C:SkinStandardWindowChrome() count("main") end
function C:SkinTab() count("tabSkin") end
function C:GetAppearanceStyle() return {} end
function C:GetAppearanceBorderColor() return {} end
function C:GetTabGroup(id) return groups[id] end
function C:ApplyTabGroupLayout() end
function C:RefreshTabGroupBaseline() end
function C:RegisterTabGroup(id) groups[id] = true; return true end
function C:RegisterSkinningElement(id, element) registry[id] = element; return true end
function C:GetSkinningElement(id) return registry[id] end
function C:RegisterActionButton(d) count("register"); registry[d.id] = d; return d end
function C:RegisterAccessoryGroup(d)
    count("register")
    return { Refresh = function() count(d.appearanceWindowID) end }
end
function C:RegisterPaginationGroup(d)
    count("paginationRegister")
    return { Refresh = function() count(d.appearanceWindowID) end }
end
function C:SkinPagingControls() end
function C:HideTextureRegions() end
assert(loadfile("Skins/NSkin_Collections.lua"))("NSkin", C)
clear()
assert(C.module:Initialize())
eq(counts.register, 5, "persistent controls initialized once")
clear()
for _ = 1, 10 do callbacks["CollectionsJournal.OnShow"]() end
eq(counts.main, 10, "reopen refreshes Main")
eq(counts.register, nil, "reopen has no persistent registration")
eq(counts["Collections.MountJournal"], 10, "reopen active page only")
eq(counts["Collections.PetJournal"], nil, "hidden page untouched")
clear()
selectedTab = 2
callbacks["CollectionsJournal.TabSet"](nil, selectedTab)
eq(counts.main, nil, "tab switch skips window chrome")
eq(counts["Collections.PetJournal"], 1, "selectedTab selects Pet adapter")
eq(counts["Collections.MountJournal"], nil, "old adapter untouched")
eq(counts.register, nil, "tab switch skips registration")
_G.WarbandSceneJournal = frame()
selectedTab = 6
callbacks["CollectionsJournal.TabSet"](nil, selectedTab)
callbacks["CollectionsJournal.TabSet"](nil, selectedTab)
eq(counts.paginationRegister, 1, "late adapter initialized once")
print("Optimization Pass 1 Collections lifecycle tests passed")
