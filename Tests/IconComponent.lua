-- Run from the repository root with Lua 5.4 (no WoW client required).
local profile = {}
local function eq(actual, expected, message)
    assert(actual == expected, message .. ": " .. tostring(actual))
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
        borderSize = 1, borderPadding = 0, width = 24, height = 20,
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

local originalButtonPoint = { button:GetPoint(1) }
local originalTexturePoint = { texture:GetPoint(1) }
local element = assert(N:RegisterIcon({
    id = "Test.Icon",
    module = "Test",
    appearanceWindowID = "Test",
    window = window,
    target = button,
}))

eq(element.kind, "ICON", "icon uses shared typed component")
eq(element.target, texture, "texture owns movable presentation geometry")
eq(element.iconTarget, button, "logical control remains the skin target")
eq(element.borderOwner, button, "logical control owns border regions")
eq(element.highlightRegions[1], texture, "Skinning Mode highlights texture")
eq(element.pixelBorderTargets[1], button, "resnap follows border owner")
eq(element.preserveAnchorSpan, true, "icon placement preserves anchor spans")
eq(texture.width, 24, "appearance width applies to texture")
eq(texture.height, 20, "appearance height applies to texture")
eq(button.width, 64, "appearance width does not resize button")
eq(button.height, 64, "appearance height does not resize button")
eq(button:GetPoint(1), originalButtonPoint[1],
    "registration does not move button")

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
    width = 18, height = 16, zoom = 0.2,
} } } }
N:InvalidateAppearance({ scope = "element", elementID = "Test.Icon" })
assert(N:RefreshTypedElement(element, "layout"))
eq(texture.width, 18, "layout refresh updates texture width immediately")
eq(texture.height, 16, "layout refresh updates texture height immediately")
eq(button.width, 64, "layout refresh still preserves button width")

local styledLeft = texture.texCoords[1]
texture:SetTexCoord(0, 1, 0, 1)
eq(texture.texCoords[1], styledLeft,
    "Blizzard texcoord update is immediately restyled")
texture:SetTexture(12345)
eq(texture.texCoords[1], styledLeft,
    "Blizzard texture update preserves NSkin crop")

local borderCount = #button.createdTextures
local repeated = assert(N:RegisterIcon({
    id = "Test.Icon",
    module = "Test",
    appearanceWindowID = "Test",
    window = window,
    target = button,
}))
eq(repeated, element, "repeated registration preserves canonical element")
eq(#button.createdTextures, borderCount,
    "repeated registration does not duplicate border regions")

assert(N:SkinIcon(button, { texture = texture, reset = true }))
eq(texture.width, 32, "appearance reset restores Blizzard width")
eq(texture.height, 32, "appearance reset restores Blizzard height")
eq(texture.texCoords[1], 0, "appearance reset restores Blizzard crop")
eq(border.top.shown, false, "appearance reset hides NSkin border")
texture:SetTexCoord(0.05, 0.95, 0.05, 0.95)
eq(texture.texCoords[1], 0.05,
    "inactive icon does not overwrite later Blizzard texcoords")
local reapplied = assert(N:RegisterIcon({
    id = "Test.Icon",
    module = "Test",
    appearanceWindowID = "Test",
    window = window,
    target = button,
}))
eq(reapplied, element, "registration after reset preserves canonical element")
eq(texture.width, 18, "registration after reset reapplies current appearance")
eq(texture.texCoords[1], styledLeft,
    "registration after reset reactivates texture maintenance")

local directButton = NewFrame(window)
directButton.objectType = "Button"
local directTexture = NewRegion("Texture", directButton)
directButton.Icon = directTexture
assert(N:SkinIcon(directButton, { texture = directTexture }))
eq(directTexture.width, 24, "direct SkinIcon caller remains supported")
eq(directButton.width, 32, "direct SkinIcon does not resize its owner")

print("Shared ICON component regression tests passed")
