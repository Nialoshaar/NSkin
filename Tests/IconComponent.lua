-- Run from the repository root with Lua 5.4 (no WoW client required).
local profile = {}
local function eq(actual, expected, message)
    assert(actual == expected, message .. ": " .. tostring(actual))
end
local function near(actual, expected, message)
    assert(math.abs(actual - expected) < 0.0001,
        message .. ": " .. tostring(actual))
end

_G.wipe = function(target)
    for key in pairs(target) do target[key] = nil end
end
_G.unpack = table.unpack
_G.GetPhysicalScreenSize = function() return 1920, 1080 end

local hooks = setmetatable({}, { __mode = "k" })
_G.hooksecurefunc = function(target, method, callback)
    hooks[target] = hooks[target] or {}
    local callbacks = hooks[target][method]
    if not callbacks then
        callbacks = {}
        hooks[target][method] = callbacks
        local original = target[method]
        target[method] = function(self, ...)
            local results = { original(self, ...) }
            for i = 1, #callbacks do callbacks[i](self, ...) end
            return table.unpack(results)
        end
    end
    callbacks[#callbacks + 1] = callback
end

local function NewRegion(objectType, parent)
    local region = {
        objectType = objectType,
        parent = parent,
        width = 32,
        height = 32,
        shown = true,
        alpha = 1,
        points = { { "CENTER", parent, "CENTER", 0, 0 } },
        texCoords = { 0, 1, 0, 1 },
    }
    function region:GetObjectType() return self.objectType end
    function region:IsObjectType(kind) return self.objectType == kind end
    function region:GetParent() return self.parent end
    function region:GetSize() return self.width, self.height end
    function region:GetWidth() return self.width end
    function region:GetHeight() return self.height end
    function region:SetSize(width, height)
        self.width, self.height = width, height
    end
    function region:SetWidth(width) self.width = width end
    function region:SetHeight(height) self.height = height end
    function region:GetNumPoints() return #self.points end
    function region:GetPoint(index) return table.unpack(self.points[index]) end
    function region:ClearAllPoints() self.points = {} end
    function region:SetPoint(...)
        self.points[#self.points + 1] = { ... }
    end
    function region:GetTexCoord() return table.unpack(self.texCoords) end
    function region:SetTexCoord(...)
        self.texCoords = { ... }
        self.texCoordWrites = (self.texCoordWrites or 0) + 1
    end
    function region:SetTexture(value) self.texture = value end
    function region:SetAtlas(value) self.atlas = value end
    function region:SetColorTexture(...) self.color = { ... } end
    function region:SetSnapToPixelGrid() end
    function region:SetTexelSnappingBias() end
    function region:SetShown(shown) self.shown = shown end
    function region:Show() self.shown = true end
    function region:Hide() self.shown = false end
    function region:IsShown() return self.shown end
    function region:IsVisible() return self.shown end
    function region:GetAlpha() return self.alpha end
    function region:SetAlpha(alpha) self.alpha = alpha end
    function region:GetEffectiveScale() return 1 end
    return region
end

local function NewFrame(parent)
    local frame = NewRegion("Frame", parent)
    frame.createdTextures = {}
    function frame:CreateTexture()
        local texture = NewRegion("Texture", self)
        self.createdTextures[#self.createdTextures + 1] = texture
        return texture
    end
    function frame:HookScript() end
    function frame:SetScript(script, callback)
        self.scripts = self.scripts or {}
        self.scripts[script] = callback
    end
    function frame:GetLeft() return 0 end
    function frame:GetRight() return self.width end
    function frame:GetBottom() return 0 end
    function frame:GetTop() return self.height end
    return frame
end

_G.UIParent = NewFrame(nil)
_G.CreateFrame = function(_, _, parent) return NewFrame(parent) end

local N = { modules = {}, baseAppearance = {
    typography = { font = "Fonts\\FRIZQT__.TTF", size = 12, outline = "" },
    accent = { enabled = false, color = { 0.2, 0.6, 1, 1 } },
    window = { border = { 0.2, 0.6, 1, 1 } },
    icon = {
        border = { 0.1, 0.2, 0.3, 1 }, borderMode = "custom",
        borderSize = 1, borderPadding = 0, width = 0, height = 0,
        zoom = 0.1, crop = 1, shape = "square",
    },
} }
function N:RegisterEvent() end
function N:GetProfile() return profile end
function N:IsModuleEnabled() return true end
function N:GetModuleOptions(module, create)
    profile.moduleOptions = profile.moduleOptions or (create and {} or nil)
    if not profile.moduleOptions then return nil end
    profile.moduleOptions[module] = profile.moduleOptions[module]
        or (create and {} or nil)
    return profile.moduleOptions[module]
end

assert(loadfile("Components/NSkin_ComponentsCore.lua"))("NSkin", N)
assert(loadfile("Components/NSkin_ComponentsContent.lua"))("NSkin", N)
assert(N:RegisterAppearanceScope("Test", {}))

local window = NewFrame(_G.UIParent)
window.width, window.height = 400, 300
local button = NewFrame(window)
button.objectType = "Button"
button.width, button.height = 64, 64
local texture = NewRegion("Texture", button)
button.Icon = texture
local nativeBorder = NewRegion("Texture", button)
nativeBorder.alpha = 0.75
local hiddenNativeBorder = NewRegion("Texture", button)
hiddenNativeBorder.alpha = 0.5
hiddenNativeBorder.shown = false

local originalButtonPoint = { button:GetPoint(1) }
local originalTexturePoint = { texture:GetPoint(1) }
local element = assert(N:RegisterIcon({
    id = "Test.Icon",
    module = "Test",
    appearanceWindowID = "Test",
    window = window,
    target = button,
    nativeDecorationRegions = { nativeBorder, hiddenNativeBorder },
}))

eq(element.kind, "ICON", "icon uses shared typed component")
eq(element.target, texture, "texture owns movable presentation geometry")
eq(element.iconTarget, button, "logical control remains the skin target")
eq(element.borderOwner, button, "logical control owns border regions")
eq(element.highlightRegions[1], texture, "Skinning Mode highlights texture")
eq(element.pixelBorderTargets[1], button, "resnap follows border owner")
eq(element.preserveAnchorSpan, true, "icon placement preserves anchor spans")
eq(texture.width, 32, "zoom does not change presentation width")
eq(texture.height, 32, "zoom does not change presentation height")
near(texture.texCoords[1], 0.1, "zoom applies horizontal texture inset")
near(texture.texCoords[3], 0.1, "zoom applies vertical texture inset")
eq(button.width, 64, "appearance width does not resize button")
eq(button.height, 64, "appearance height does not resize button")
eq(button:GetPoint(1), originalButtonPoint[1],
    "registration does not move button")
eq(nativeBorder.alpha, 0, "declared native border is concealed")
nativeBorder:SetAlpha(0.4)
eq(nativeBorder.alpha, 0,
    "active native border remains concealed after Blizzard update")
hiddenNativeBorder:Show()
eq(hiddenNativeBorder.alpha, 0,
    "shown native border remains visually concealed while active")

local textureBaseline = assert(N:GetComponentBaseline("Test.Icon:texture"))
eq(textureBaseline.target, texture, "appearance baseline belongs to texture")
eq(textureBaseline.width, 32, "appearance baseline captures Blizzard width")
eq(textureBaseline.height, 32, "appearance baseline captures Blizzard height")
eq(N:GetComponentBaseline("Test.Icon").target, texture,
    "placement baseline belongs to texture")
local border = assert(N:GetPixelBorder(button, "NSkinIconBorder"))
eq(border.anchor, texture, "border anchors to texture")
assert(N:ResnapPixelBordersForElement(element),
    "element resnap reaches separate border owner")

assert(element.setPlacement(element, {
    mode = "GRID", point = "TOPLEFT", relativePoint = "TOPLEFT",
    x = 80, y = -40,
}))
eq(button:GetPoint(1), originalButtonPoint[1], "moving icon preserves button")
eq(texture:GetPoint(1), "TOPLEFT", "moving icon changes texture point")
assert(element.resetPlacement(element), "icon position reset succeeds")
eq(texture:GetPoint(1), originalTexturePoint[1],
    "icon position reset restores texture baseline")

profile.appearanceOverrides = { elements = { ["Test.Icon"] = { icon = {
    width = 40, height = 16, zoom = 0, crop = 0.8,
} } } }
N:InvalidateAppearance({ scope = "element", elementID = "Test.Icon" })
assert(N:RefreshTypedElement(element, "layout"))
eq(texture.width, 40, "layout refresh updates texture width immediately")
eq(texture.height, 32, "crop ratio changes presentation height")
eq(button.width, 64, "layout refresh still preserves button width")
near(texture.texCoords[1], 0, "crop does not add horizontal zoom")
near(texture.texCoords[3], 0.1, "crop trims texture vertically")
near((texture.texCoords[2] - texture.texCoords[1])
    / (texture.texCoords[4] - texture.texCoords[3]), 1.25,
    "crop preserves image aspect without stretching")

profile.appearanceOverrides.elements["Test.Icon"].icon.zoom = 0.1
N:InvalidateAppearance({ scope = "element", elementID = "Test.Icon" })
assert(N:RefreshTypedElementAppearance(element))
eq(texture.width, 40, "combined zoom and crop preserves width")
eq(texture.height, 32, "combined zoom and crop preserves crop height")
near(texture.texCoords[1], 0.1, "combined zoom applies horizontal inset")
near(texture.texCoords[3], 0.18,
    "combined zoom and crop applies independent vertical crop")

local styledLeft = texture.texCoords[1]
texture:SetTexCoord(0, 1, 0, 1)
eq(texture.texCoords[1], styledLeft,
    "Blizzard texcoord update is immediately restyled")
texture:SetTexture(12345)
eq(texture.texCoords[1], styledLeft,
    "Blizzard texture update preserves NSkin crop")
texture:SetSize(17, 17)
eq(texture.width, 40, "pooled size update reapplies owned width")
eq(texture.height, 32, "pooled size update reapplies cropped height")

local borderCount = #button.createdTextures
local repeated = assert(N:RegisterIcon({
    id = "Test.Icon",
    module = "Test",
    appearanceWindowID = "Test",
    window = window,
    target = button,
    nativeDecorationRegions = { nativeBorder, hiddenNativeBorder },
}))
eq(repeated, element, "repeated registration preserves canonical element")
eq(#button.createdTextures, borderCount,
    "repeated registration does not duplicate border regions")
eq(#hooks[texture].SetTexture, 1,
    "repeated registration does not duplicate texture hooks")
eq(#hooks[nativeBorder].SetAlpha, 1,
    "repeated registration does not duplicate native border hooks")

assert(N:SkinIcon(button, { texture = texture, reset = true }))
eq(texture.width, 32, "appearance reset restores Blizzard width")
eq(texture.height, 32, "appearance reset restores Blizzard height")
eq(texture.texCoords[1], 0, "appearance reset restores Blizzard crop")
eq(border.top.shown, false, "appearance reset hides NSkin border")
eq(nativeBorder.alpha, 0.75, "reset restores native border alpha")
eq(nativeBorder.shown, true, "reset restores native border visibility")
eq(hiddenNativeBorder.alpha, 0.5,
    "reset restores initially hidden native border alpha")
eq(hiddenNativeBorder.shown, false,
    "reset restores initially hidden native border visibility")
texture:SetTexCoord(0.05, 0.95, 0.05, 0.95)
eq(texture.texCoords[1], 0.05,
    "inactive icon does not overwrite later Blizzard texcoords")
local reapplied = assert(N:RegisterIcon({
    id = "Test.Icon",
    module = "Test",
    appearanceWindowID = "Test",
    window = window,
    target = button,
    nativeDecorationRegions = { nativeBorder, hiddenNativeBorder },
}))
eq(reapplied, element, "registration after reset preserves canonical element")
eq(texture.width, 40, "registration after reset reapplies current appearance")
eq(texture.height, 32, "registration after reset reapplies crop geometry")
eq(texture.texCoords[1], styledLeft,
    "registration after reset reactivates texture maintenance")
eq(nativeBorder.alpha, 0,
    "registration after reset conceals declared native border again")

local directButton = NewFrame(window)
directButton.objectType = "Button"
local directTexture = NewRegion("Texture", directButton)
directButton.Icon = directTexture
local legacyNativeBorder = NewRegion("Texture", directButton)
legacyNativeBorder.alpha = 0.6
assert(N:SkinIcon(directButton, {
    texture = directTexture,
    nativeBorderRegions = { legacyNativeBorder },
}))
eq(directTexture.width, 32, "direct SkinIcon caller remains supported")
eq(directButton.width, 32, "direct SkinIcon does not resize its owner")
eq(legacyNativeBorder.alpha, 0,
    "legacy nativeBorderRegions remains compatible")
assert(N:SkinIcon(directButton, { texture = directTexture, reset = true }))
eq(legacyNativeBorder.alpha, 0.6,
    "legacy nativeBorderRegions decoration resets")

print("Shared ICON component regression tests passed")
