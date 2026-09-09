do
local _, NSkin = ...

local resolvedStyles = {}
local appearanceScopes = {}
local appearanceScopeChains = {}
local resolvedAppearanceStyles = {}
local appearanceGeneration = 0
local appearanceStyleRevisions = {}
local appearanceWindowRevisions = {}
local appearanceElementRevisions = {}
local GetGlobalAppearanceChangeScope

local function RoundOne(value)
    value = tonumber(value) or 0
    if value >= 0 then return math.floor(value * 10 + 0.5) / 10 end
    return math.ceil(value * 10 - 0.5) / 10
end

local function TablesEqual(left, right)
    if left == right then return true end
    if type(left) ~= type(right) then return false end
    if type(left) ~= "table" then return left == right end
    for key, value in pairs(left) do
        if not TablesEqual(value, right[key]) then return false end
    end
    for key in pairs(right) do
        if left[key] == nil then return false end
    end
    return true
end

local function GetPath(root, path, create)
    local node = root
    local parent
    local finalKey
    for key in path:gmatch("[^%.]+") do
        parent = node
        finalKey = key
        local child = node[key]
        if child == nil and create then
            child = {}
            node[key] = child
        end
        node = child
        if node == nil then break end
    end
    return node, parent, finalKey
end

local function PruneEmptyTables(root)
    for key, value in pairs(root) do
        if type(value) == "table" then
            PruneEmptyTables(value)
            if not next(value) then root[key] = nil end
        end
    end
end

local function CopyWithOverrides(defaults, overrides)
    local result = {}
    for key, defaultValue in pairs(defaults) do
        local override = overrides and overrides[key]
        if type(defaultValue) == "table" then
            result[key] = CopyWithOverrides(
                defaultValue,
                type(override) == "table" and override or nil
            )
        elseif override ~= nil then
            result[key] = override
        else
            result[key] = defaultValue
        end
    end
    for key, override in pairs(overrides or {}) do
        if defaults[key] == nil then
            result[key] = type(override) == "table"
                and CopyWithOverrides({}, override) or override
        end
    end
    return result
end

function NSkin:GetStyle(name)
    local cached = resolvedStyles[name]
    if cached then return cached end

    local defaults = self.baseAppearance and self.baseAppearance[name]
    if type(defaults) ~= "table" then return nil end

    local profile = self:GetProfile()
    local overrides = profile.appearance and profile.appearance[name]
    cached = CopyWithOverrides(defaults, overrides)
    resolvedStyles[name] = cached
    return cached
end

local function GetAppearanceScopeChain(scopeID)
    if not scopeID then return nil end
    local cached = appearanceScopeChains[scopeID]
    if cached then return cached end
    local chain, seen = {}, {}
    local current = scopeID
    while current do
        if seen[current] then return nil end
        seen[current] = true
        table.insert(chain, 1, current)
        local scope = appearanceScopes[current]
        if not scope then return nil end
        current = scope.parent
    end
    appearanceScopeChains[scopeID] = chain
    return chain
end

function NSkin:RegisterAppearanceScope(scopeID, definition)
    if type(scopeID) ~= "string" or scopeID == ""
        or type(definition) ~= "table" or appearanceScopes[scopeID]
    then return false end
    local parent = definition.parent
    if parent ~= nil and (type(parent) ~= "string"
        or parent == "" or not appearanceScopes[parent])
    then return false end
    if parent == scopeID then return false end
    local scope = {
        id = scopeID,
        label = definition.label or scopeID,
        parent = parent,
    }
    appearanceScopes[scopeID] = scope
    if not GetAppearanceScopeChain(scopeID) then
        appearanceScopes[scopeID] = nil
        return false
    end
    -- Scope registration is the only hierarchy mutation currently supported.
    -- Drop cached chains so future hierarchy operations remain safe as well.
    appearanceScopeChains = {}
    return true
end

function NSkin:GetAppearanceScope(scopeID)
    return appearanceScopes[scopeID]
end

function NSkin:GetAppearanceScopeChain(scopeID)
    local chain = GetAppearanceScopeChain(scopeID)
    if not chain then return nil end
    local copy = {}
    for i = 1, #chain do copy[i] = chain[i] end
    return copy
end

-- Appearance resolves from the base appearance through optional window
-- and element layers. Each saved layer remains sparse, so reset means removal.
function NSkin:GetAppearanceStyle(name, windowID, elementID)
    local byWindow = resolvedAppearanceStyles[name]
    local windowKey = windowID or false
    local elementKey = elementID or false
    local byElement = byWindow and byWindow[windowKey]
    local cached = byElement and byElement[elementKey]
    local chain = windowID and GetAppearanceScopeChain(windowID)
    local valid = cached
        and cached.generation == appearanceGeneration
        and cached.styleRevision == (appearanceStyleRevisions[name] or 0)
        and cached.elementRevision == (appearanceElementRevisions[elementID] or 0)
    if valid then
        for i = 1, #(chain or {}) do
            if cached.windowRevisions[i]
                ~= (appearanceWindowRevisions[chain[i]] or 0)
            then
                valid = false
                break
            end
        end
    end
    if valid then return CopyWithOverrides({}, cached.style) end

    local style = self:GetStyle(name)
    if not style then return nil end
    -- baseAppearance contains styling only. GetStyle() adds the sparse global
    -- profile layer, whose explicit geometry must remain available to every
    -- compatible component before window and element overrides are applied.
    style = CopyWithOverrides({}, style)
    local profile = self:GetProfile()
    local overrides = profile.appearanceOverrides
    for i = 1, #(chain or {}) do
        local windowOverride = overrides and overrides.windows
            and overrides.windows[chain[i]]
        if windowOverride and windowOverride[name] then
            style = CopyWithOverrides(style, windowOverride[name])
        end
    end
    local elementOverride = elementID and overrides and overrides.elements
        and overrides.elements[elementID]
    if elementOverride and elementOverride[name] then
        style = CopyWithOverrides(style, elementOverride[name])
    end
    byWindow = byWindow or {}
    resolvedAppearanceStyles[name] = byWindow
    byElement = byElement or {}
    byWindow[windowKey] = byElement
    local windowRevisions = {}
    for i = 1, #(chain or {}) do
        windowRevisions[i] = appearanceWindowRevisions[chain[i]] or 0
    end
    byElement[elementKey] = {
        style = style,
        generation = appearanceGeneration,
        styleRevision = appearanceStyleRevisions[name] or 0,
        elementRevision = appearanceElementRevisions[elementID] or 0,
        windowRevisions = windowRevisions,
    }
    -- Resolved styles are cache templates. Callers receive an isolated copy so
    -- a component cannot mutate the value observed by another element.
    return CopyWithOverrides({}, style)
end

function NSkin:GetResolvedTypography(style, prefix)
    style = style or {}
    prefix = prefix or ""
    local useGlobalKey = prefix == "" and "useGlobalTypography"
        or (prefix .. "UseGlobalTypography")
    local fontKey = prefix == "" and "font" or (prefix .. "Font")
    local sizeKey = prefix == "" and "textSize" or (prefix .. "Size")
    local outlineKey = prefix == "" and "outline" or (prefix .. "Outline")
    local global = self:GetStyle("typography")
    local fontModeKey = prefix == "" and "fontMode" or prefix .. "FontMode"
    local sizeModeKey = prefix == "" and "sizeMode" or prefix .. "SizeMode"
    local outlineModeKey = prefix == "" and "outlineMode" or prefix .. "OutlineMode"
    if style[fontModeKey] or style[sizeModeKey] or style[outlineModeKey] then
        local font = style[fontModeKey] == "GLOBAL" and global.font
            or style[fontKey] or global.font
        local size
        if style[sizeModeKey] ~= "BLIZZARD" then
            size = style[sizeModeKey] == "GLOBAL" and global.size
                or style[sizeKey] or global.size
        end
        local outline = style[outlineModeKey] == "GLOBAL" and global.outline
            or style[outlineKey] or global.outline
        return font, size, outline
    elseif style[useGlobalKey] == true then
        return global.font, global.size, global.outline
    end
    return style[fontKey] or global.font, style[sizeKey] or global.size,
        style[outlineKey] or global.outline
end

function NSkin:SkinTextColor(fontString, style)
    if not fontString or not fontString.GetFont then return false end
    style = style or self:GetStyle("text")
    local color = self:GetResolvedAppearanceColor(style, "color")
    if color then self:SetFontStringColor(fontString, unpack(color)) end
    return true
end

local function FormatGroupedNumber(value)
    local numeric = tonumber(value)
    if not numeric then return value end
    if type(_G.BreakUpLargeNumbers) == "function" then
        local ok, formatted = pcall(_G.BreakUpLargeNumbers, numeric)
        if ok and formatted ~= nil then return tostring(formatted) end
    end
    if type(_G.FormatLargeNumber) == "function" then
        local ok, formatted = pcall(_G.FormatLargeNumber, numeric)
        if ok and formatted ~= nil then return tostring(formatted) end
    end
    local sign = numeric < 0 and "-" or ""
    local digits = tostring(math.floor(math.abs(numeric)))
    local separator = _G.LARGE_NUMBER_SEPERATOR
        or _G.LARGE_NUMBER_SEPARATOR or " "
    local grouped = digits:reverse():gsub("(%d%d%d)", "%1" .. separator)
        :reverse():gsub("^" .. separator, "")
    return sign .. grouped
end

local function FormatSharedTextValue(value, numberFormat, suffixIcon)
    if value == nil then return nil end
    local text = tostring(value)
    local number = text:match("^%s*([+-]?%d+)%s*$")
    if not number then return text end
    local formatted = string.upper(tostring(numberFormat or "")) == "GOLD"
        and FormatGroupedNumber(number) or text
    if string.upper(tostring(suffixIcon or "")) ~= "GOLD" then
        return formatted
    end
    local textureFormat = _G.GOLD_AMOUNT_TEXTURE_STRING
        or _G.GOLD_AMOUNT_TEXTURE
    if type(textureFormat) == "string" then
        local ok, result = pcall(string.format,
            textureFormat, formatted, 0, 0)
        if ok then return result end
    end
    return formatted .. (_G.GOLD_AMOUNT_SYMBOL or "g")
end

local function RefreshSharedTextFormatting(fontString)
    local data = NSkin:GetSkinData(fontString, "sharedTextFormatting", false)
    if not data or not data.active or data.applying then return end
    local formatted = FormatSharedTextValue(
        data.rawText, data.numberFormat, data.suffixIcon)
    data.formattedText = formatted
    if fontString.GetText and fontString:GetText() == formatted then return end
    data.applying = true
    fontString:SetText(formatted)
    data.applying = nil
end

local function ApplySharedTextFormatting(fontString, options)
    local active = options and (options.numberFormat or options.suffixIcon)
    local data = NSkin:GetSkinData(
        fontString, "sharedTextFormatting", active ~= nil)
    if not data then return end
    local current = fontString.GetText and fontString:GetText()
    if current ~= data.formattedText then data.rawText = current end
    data.numberFormat = options and options.numberFormat
    data.suffixIcon = options and options.suffixIcon
    data.active = active and true or nil
    if not data.active then
        if current == data.formattedText and fontString.SetText then
            data.applying = true
            fontString:SetText(data.rawText)
            data.applying = nil
        end
        data.formattedText = nil
        return
    end
    if not data.hooked and _G.hooksecurefunc
        and type(fontString.SetText) == "function"
    then
        _G.hooksecurefunc(fontString, "SetText", function(_, value)
            if data.applying then return end
            data.rawText = value
            RefreshSharedTextFormatting(fontString)
        end)
        data.hooked = true
    end
    RefreshSharedTextFormatting(fontString)
end

function NSkin:SkinText(fontString, style, options)
    if not self:SkinTextColor(fontString, style) then return false end
    style = style or self:GetStyle("text")
    self:ApplyResolvedTypography(fontString, style)
    ApplySharedTextFormatting(fontString, options)
    return true
end

function NSkin:ApplyResolvedTypography(fontString, style, prefix)
    if not fontString or not fontString.GetFont or not fontString.SetFont then return false end
    local data = self:GetSkinData(fontString, "resolvedTypography")
    if not data.baselineID then
        data.baselineID = "Typography:" .. tostring(fontString)
        self:CaptureComponentBaseline(data.baselineID, fontString, {
            font = fontString,
        })
    end
    local baseline = self:GetComponentBaseline(data.baselineID)
    if not data.originalFont then
        data.originalFont = baseline and baseline.font or { fontString:GetFont() }
    end
    local font, size, outline = self:GetResolvedTypography(style, prefix)
    local hasSizeOverride = tonumber(size) ~= nil
    font = font or data.originalFont[1]
    size = tonumber(size) or data.originalFont[2]
    if not font or not size then return false end
    local resolvedOutline = outline ~= nil and outline or data.originalFont[3]
    self:MarkComponentGeometryModified(data.baselineID, "font",
        hasSizeOverride)
    local currentFont, currentSize, currentOutline = fontString:GetFont()
    if currentFont ~= font or currentSize ~= size
        or currentOutline ~= resolvedOutline
    then
        fontString:SetFont(font, size, resolvedOutline)
    end
    return true
end

function NSkin:GetResolvedAppearanceColor(style, key)
    local color = style and style[key]
    if type(color) ~= "table" then return color end
    local mode = style[key .. "Mode"]
    local resolved
    if mode == "ACCENT" then
        resolved = self:GetAccentColor()
    elseif mode == "CLASS" then
        local _, class = UnitClass("player")
        resolved = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    end
    if not resolved then return color end
    return { resolved.r or resolved[1], resolved.g or resolved[2],
        resolved.b or resolved[3], color[4] or resolved.a or resolved[4] or 1 }
end

local function GetAppearanceParentValue(scope, id, windowID, path)
    local styleName, relativePath = path:match("^([^.]+)%.(.+)$")
    if not styleName then return nil end
    local style
    if scope == "windows" then
        local registered = appearanceScopes[id]
        style = registered and registered.parent
            and NSkin:GetAppearanceStyle(styleName, registered.parent)
            or NSkin:GetStyle(styleName)
    else
        style = NSkin:GetAppearanceStyle(styleName, windowID)
    end
    return style and GetPath(style, relativePath, false), styleName, relativePath
end

local function SetAppearanceOverride(scope, id, windowID, path, value)
    if (scope ~= "windows" and scope ~= "elements")
        or type(id) ~= "string" or id == ""
        or type(path) ~= "string" or path == ""
    then
        return false
    end
    local parentValue, styleName, relativePath =
        GetAppearanceParentValue(scope, id, windowID, path)
    if parentValue ~= nil and type(parentValue) ~= type(value) then return false end

    local profile = NSkin:GetProfile()
    local scopes = profile.appearanceOverrides
    local styleOverrides = scopes and scopes[scope] and scopes[scope][id]
        and scopes[scope][id][styleName]
    local currentValue = styleOverrides
        and GetPath(styleOverrides, relativePath, false) or nil
    local isBlizzardGeometrySentinel = value == 0
        and (path:match("%.width$") or path:match("%.height$")
            or path:match("%.textSize$") or path:match("%.iconSize$"))
    local newValue = (isBlizzardGeometrySentinel
        or (parentValue ~= nil and TablesEqual(value, parentValue)))
        and nil or value
    if TablesEqual(currentValue, newValue) then return false end

    profile.appearanceOverrides = profile.appearanceOverrides or {}
    scopes = profile.appearanceOverrides
    scopes[scope] = scopes[scope] or {}
    scopes[scope][id] = scopes[scope][id] or {}
    scopes[scope][id][styleName] = scopes[scope][id][styleName] or {}
    styleOverrides = scopes[scope][id][styleName]
    local _, parent, key = GetPath(styleOverrides, relativePath, true)
    parent[key] = newValue
    PruneEmptyTables(profile.appearanceOverrides)
    if not next(profile.appearanceOverrides) then profile.appearanceOverrides = nil end
    local liveInspectorElementID = NSkin._liveInspectorAppearanceElementID
    NSkin:RefreshAppearance({
        scope = scope == "elements" and "element" or "window",
        elementID = scope == "elements" and id or nil,
        windowID = windowID or (scope == "windows" and id or nil),
        style = styleName, path = relativePath,
        origin = scope == "elements" and liveInspectorElementID == id
            and "activeInspectorLive" or nil,
    })
    return true
end

local function CollectResetChanges(changes, styleName, value, prefix)
    if type(value) ~= "table" then
        changes[#changes + 1] = { style = styleName, path = prefix }
        return
    end
    for key, child in pairs(value) do
        local childPath = prefix and (prefix .. "." .. tostring(key)) or tostring(key)
        CollectResetChanges(changes, styleName, child, childPath)
    end
end

local function ResetAppearanceOverride(scope, id, path)
    if type(id) ~= "string" or id == "" then return false end
    local profile = NSkin:GetProfile()
    local scopes = profile.appearanceOverrides
    local overrides = scopes and scopes[scope] and scopes[scope][id]
    if not overrides then return false end
    local changed
    local changes = {}
    if path == nil then
        for styleName, styleOverrides in pairs(overrides) do
            CollectResetChanges(changes, styleName, styleOverrides)
        end
        scopes[scope][id] = nil
        changed = true
    else
        local paths = type(path) == "table" and path or { path }
        for i = 1, #paths do
            local styleName, relativePath = paths[i]:match("^([^.]+)%.(.+)$")
            local styleOverrides = styleName and overrides[styleName]
            if styleOverrides then
                local current, parent, key = GetPath(
                    styleOverrides, relativePath, false)
                if parent and current ~= nil then
                    parent[key] = nil
                    changed = true
                    changes[#changes + 1] = {
                        style = styleName,
                        path = relativePath,
                    }
                end
            end
        end
    end
    if not changed then return false end
    PruneEmptyTables(profile.appearanceOverrides)
    if not next(profile.appearanceOverrides) then profile.appearanceOverrides = nil end
    local element = scope == "elements" and NSkin:GetSkinningElement(id)
    local change = {
        scope = scope == "elements" and "element" or "window",
        elementID = scope == "elements" and id or nil,
        windowID = element and element.appearanceWindowID
            or (scope == "windows" and id or nil),
        changes = changes,
    }
    if #changes == 1 then
        change.style = changes[1].style
        change.path = changes[1].path
    end
    NSkin:RefreshAppearance(change)
    return true
end

function NSkin:SetWindowAppearanceOverride(windowID, path, value)
    if not appearanceScopes[windowID] then return false end
    return SetAppearanceOverride("windows", windowID, nil, path, value)
end

function NSkin:ResetWindowAppearanceOverride(windowID, path)
    if not appearanceScopes[windowID] then return false end
    return ResetAppearanceOverride("windows", windowID, path)
end

function NSkin:SetElementAppearanceOverride(elementID, windowID, path, value)
    if not appearanceScopes[windowID] then return false end
    return SetAppearanceOverride("elements", elementID, windowID, path, value)
end

function NSkin:ResetElementAppearanceOverride(elementID, path)
    return ResetAppearanceOverride("elements", elementID, path)
end

function NSkin:ResetElementAppearanceOverrides(elementID, paths)
    return ResetAppearanceOverride("elements", elementID, paths)
end

function NSkin:GetBorderAccentColor()
    return self:GetStyle("window").border
end

function NSkin:SetBorderAccentColor(color)
    if type(color) ~= "table" then return false end
    return self:SetAppearanceOverride("window.border", color)
end

function NSkin:ResetBorderAccentColor()
    return self:ResetAppearanceOverride("window.border")
end

function NSkin:IsAccentColorEnabled()
    return self:GetStyle("accent").enabled == true
end

function NSkin:GetAccentColor()
    return self:GetStyle("accent").color
end

function NSkin:SetAccentColorEnabled(enabled)
    return self:SetAppearanceOverride("accent.enabled", enabled == true)
end

function NSkin:SetAccentColor(color)
    if type(color) ~= "table" then return false end
    return self:SetAppearanceOverride("accent.color", color)
end

function NSkin:ResetAccentColor()
    return self:ResetAppearanceOverride("accent.color")
end

function NSkin:GetSharedBorderColor()
    if self:IsAccentColorEnabled() then return self:GetAccentColor() end
    return self:GetBorderAccentColor()
end

function NSkin:GetComponentBorderSetting(styleName, style)
    local profile = self:GetProfile()
    local override = profile.appearance and profile.appearance[styleName]
        and profile.appearance[styleName].border
    if override ~= nil then
        style = style or self:GetStyle(styleName)
        if style and style.border then return style.border end
    end
    return self:GetBorderAccentColor()
end

function NSkin:GetComponentBorderColor(styleName, style)
    if self:IsAccentColorEnabled() then return self:GetAccentColor() end
    return self:GetComponentBorderSetting(styleName, style)
end

function NSkin:GetAppearanceBorderColor(styleName, style, windowID, elementID)
    if style and style.borderMode then
        return self:GetResolvedAppearanceColor(style, "border")
    end
    local profile = self:GetProfile()
    local overrides = profile.appearanceOverrides
    local elementBorder = elementID and overrides and overrides.elements
        and overrides.elements[elementID] and overrides.elements[elementID][styleName]
        and overrides.elements[elementID][styleName].border
    if elementBorder ~= nil then return style.border end
    local chain = windowID and GetAppearanceScopeChain(windowID)
    for i = #(chain or {}), 1, -1 do
        local windowBorder = overrides and overrides.windows
            and overrides.windows[chain[i]]
            and overrides.windows[chain[i]][styleName]
            and overrides.windows[chain[i]][styleName].border
        if windowBorder ~= nil then return style.border end
    end
    return self:GetComponentBorderColor(styleName, style)
end

function NSkin:SetComponentBorderColor(styleName, color)
    local defaults = self.baseAppearance and self.baseAppearance[styleName]
    if type(color) ~= "table" or type(defaults) ~= "table"
        or type(defaults.border) ~= "table"
    then
        return false
    end
    local profile = self:GetProfile()
    local current = profile.appearance and profile.appearance[styleName]
        and profile.appearance[styleName].border
    local newValue = TablesEqual(color, self:GetBorderAccentColor()) and nil or color
    if TablesEqual(current, newValue) then return false end
    profile.appearance = profile.appearance or {}
    profile.appearance[styleName] = profile.appearance[styleName] or {}
    profile.appearance[styleName].border = newValue
    PruneEmptyTables(profile.appearance)
    if not next(profile.appearance) then profile.appearance = nil end
    self:RefreshAppearance({
        scope = GetGlobalAppearanceChangeScope(self, styleName),
        style = styleName,
        path = "border",
    })
    return true
end

function NSkin:ResetComponentBorderColor(styleName)
    return self:ResetAppearanceOverride(styleName .. ".border")
end

function NSkin:GetWindowBorderColor()
    return self:GetSharedBorderColor()
end

function NSkin:GetTabSpacing()
    return self:GetStyle("tab").spacing
end

local function RefreshTabLayouts()
    NSkin:InvalidateAppearance({ scope = "type", style = "tab" })
    if NSkin.RefreshRegisteredTabGroups then NSkin:RefreshRegisteredTabGroups() end
end

local function SetTabLayoutOverride(path, value)
    local defaultValue = GetPath(NSkin.baseAppearance, path, false)
    local profile = NSkin:GetProfile()
    local currentValue = profile.appearance
        and GetPath(profile.appearance, path, false) or nil
    local newValue = value == defaultValue and nil or value
    if TablesEqual(currentValue, newValue) then return false end
    profile.appearance = profile.appearance or {}
    local _, parent, key = GetPath(profile.appearance, path, true)
    parent[key] = newValue
    PruneEmptyTables(profile.appearance)
    if not next(profile.appearance) then profile.appearance = nil end
    RefreshTabLayouts()
    return true
end

function NSkin:SetTabSpacing(spacing)
    spacing = tonumber(spacing)
    if not spacing then return false end
    spacing = math.max(-30, math.min(30, math.floor(spacing + 0.5)))
    return SetTabLayoutOverride("tab.spacing", spacing)
end

function NSkin:ResetTabSpacing()
    return self:ResetAppearanceOverride("tab.spacing")
end

function NSkin:GetBottomTabAnchor()
    local bottom = self:GetStyle("tab").bottom
    return bottom and bottom.anchor or nil
end

function NSkin:GetBottomTabOffsetX()
    local bottom = self:GetStyle("tab").bottom
    return bottom and bottom.offsetX or nil
end

function NSkin:GetBottomTabOffsetY()
    local bottom = self:GetStyle("tab").bottom
    return bottom and bottom.offsetY or nil
end

function NSkin:GetTabPlacement()
    local layout = self:GetStyle("tab").bottom or {}
    return {
        mode = layout.mode,
        point = layout.point,
        relativePoint = layout.relativePoint,
        x = layout.x,
        y = layout.y,
        edge = layout.edge or "BOTTOM",
        side = layout.side or "OUTSIDE",
        alignment = layout.anchor or "LEFT",
        alongOffset = layout.offsetX or 0,
        edgeOffset = layout.offsetY or 0,
    }
end

function NSkin:SetTabPlacement(placement)
    if type(placement) ~= "table" then return false end
    local profile = self:GetProfile()
    profile.appearance = profile.appearance or {}
    profile.appearance.tab = profile.appearance.tab or {}
    profile.appearance.tab.bottom = profile.appearance.tab.bottom or {}
    local bottom = profile.appearance.tab.bottom
    if placement.mode == "GRID" then
        local x, y = tonumber(placement.x), tonumber(placement.y)
        if not x or not y then return false end
        bottom.mode = "GRID"
        bottom.point = placement.point or "TOPLEFT"
        bottom.relativePoint = placement.relativePoint or "TOPLEFT"
        bottom.x = math.max(-2000, math.min(2000, RoundOne(x)))
        bottom.y = math.max(-2000, math.min(2000, RoundOne(y)))
        bottom.relativeTo = nil
        RefreshTabLayouts()
        return true
    end
    local alignment = placement.alignment
    if alignment ~= "LEFT" and alignment ~= "CENTER" and alignment ~= "RIGHT" then
        return false
    end
    local current = self:GetTabPlacement()
    local edge = placement.edge or current.edge
    local side = placement.side or current.side
    if edge ~= "TOP" and edge ~= "BOTTOM" then return false end
    if side ~= "INSIDE" and side ~= "OUTSIDE" then return false end
    local alongOffset = tonumber(placement.alongOffset)
    local edgeOffset = tonumber(placement.edgeOffset)
    if not alongOffset or not edgeOffset then return false end
    alongOffset = math.max(-2000, math.min(2000, RoundOne(alongOffset)))
    edgeOffset = math.max(-2000, math.min(2000, RoundOne(edgeOffset)))

    bottom.mode, bottom.point, bottom.relativePoint, bottom.x, bottom.y = nil, nil, nil, nil, nil
    bottom.edge = edge
    bottom.side = side
    bottom.anchor = alignment
    bottom.offsetX = alongOffset
    bottom.offsetY = edgeOffset
    PruneEmptyTables(profile.appearance)
    if not next(profile.appearance) then profile.appearance = nil end
    RefreshTabLayouts()
    return true
end

function NSkin:GetBottomTabPlacement()
    return self:GetTabPlacement()
end

function NSkin:SetBottomTabPlacement(placement)
    return self:SetTabPlacement(placement)
end

function NSkin:SetBottomTabAnchor(anchor)
    if anchor ~= "LEFT" and anchor ~= "CENTER" and anchor ~= "RIGHT" then
        return false
    end
    local placement = self:GetTabPlacement()
    placement.alignment = anchor
    return self:SetTabPlacement(placement)
end

function NSkin:SetBottomTabOffsetX(offset)
    offset = tonumber(offset)
    if not offset then return false end
    local placement = self:GetTabPlacement()
    placement.alongOffset = offset
    return self:SetTabPlacement(placement)
end

function NSkin:SetBottomTabOffsetY(offset)
    offset = tonumber(offset)
    if not offset then return false end
    local placement = self:GetTabPlacement()
    placement.edgeOffset = offset
    return self:SetTabPlacement(placement)
end

function NSkin:ResetTabLayout()
    local changed = self:ResetAppearanceOverride("tab.bottom")
    if self.ForEachRegisteredTabGroup then
        self:ForEachRegisteredTabGroup(function(group)
            self:RestoreTabGroupOriginalPlacement(group.id)
        end)
    end
    return changed
end


function NSkin:ResetBottomTabLayout()
    return self:ResetTabLayout()
end

function NSkin:InvalidateAppearance(change)
    if change and change.scope == "element" and change.elementID then
        appearanceElementRevisions[change.elementID] =
            (appearanceElementRevisions[change.elementID] or 0) + 1
        return
    end
    if change and change.scope == "window" and change.windowID then
        appearanceWindowRevisions[change.windowID] =
            (appearanceWindowRevisions[change.windowID] or 0) + 1
        return
    end
    if change and change.scope == "type" then
        local styleName = change.style
        if not styleName and change.typeID and self.GetSharedElementType then
            local definition = self:GetSharedElementType(change.typeID)
            styleName = definition and definition.style
        end
        if styleName then
            resolvedStyles[styleName] = nil
            appearanceStyleRevisions[styleName] =
                (appearanceStyleRevisions[styleName] or 0) + 1
            return
        end
    end
    appearanceGeneration = appearanceGeneration + 1
    wipe(resolvedStyles)
    wipe(resolvedAppearanceStyles)
end

local LAYOUT_APPEARANCE_KEYS = {
    width = true,
    height = true,
    size = true,
    textSize = true,
    iconSize = true,
    spacing = true,
}

local function ClassifyAppearanceRequirement(change)
    if not change then return "structural" end
    if change.requirement == "appearance" or change.requirement == "layout"
        or change.requirement == "structural"
    then
        return change.requirement
    end
    local entries = change.changes or { change }
    for i = 1, #entries do
        local path = entries[i].path
        local key = type(path) == "string" and path:match("([^.]+)$")
        if key and LAYOUT_APPEARANCE_KEYS[key] then return "layout" end
    end
    return "appearance"
end

local function ChangeMatchesStyle(change, styleName)
    if not change or not styleName then return false end
    if change.style and change.style ~= styleName then return false end
    local entries = change.changes
    if entries then
        for i = 1, #entries do
            if entries[i].style and entries[i].style ~= styleName then
                return false
            end
        end
    end
    return true
end

local function StyleMatchesFamily(changeStyle, elementStyle)
    if type(changeStyle) ~= "string" or type(elementStyle) ~= "string" then
        return false
    end
    return elementStyle == changeStyle
        or elementStyle:sub(1, #changeStyle + 1) == changeStyle .. "."
end

local function ChangeAffectsStyleFamily(change, elementStyle)
    if change.style then return StyleMatchesFamily(change.style, elementStyle) end
    for i = 1, #(change.changes or {}) do
        if StyleMatchesFamily(change.changes[i].style, elementStyle) then return true end
    end
    return false
end

local function ContainsAppearanceValue(values, expected)
    for i = 1, #(values or {}) do
        if values[i] == expected then return true end
    end
    return false
end

local function ChangeMatchesSharedType(change, element, sharedType, allowStyleFamily)
    if change.typeID and element.kind ~= change.typeID
        and not ContainsAppearanceValue(
            element.appearanceTypeIDs, change.typeID)
    then
        return false
    end
    local styles = { sharedType.style }
    for i = 1, #(element.appearanceStyles or {}) do
        styles[#styles + 1] = element.appearanceStyles[i]
    end
    if allowStyleFamily and (change.style or change.changes) then
        for i = 1, #styles do
            if ChangeAffectsStyleFamily(change, styles[i]) then return true end
        end
        return false
    end
    for i = 1, #styles do
        if ChangeMatchesStyle(change, styles[i]) then return true end
    end
    return false
end

local function RecordAppearanceFallback(change, reason)
    if NSkin.DebugAppearanceRefresh then
        NSkin:DebugAppearanceRefresh(change, reason)
    end
end

local function RefreshElementForChange(self, element, change, allowStyleFamily)
    local module = element and self.modules[element.module]
    local sharedType = element and self:GetSharedElementType(element.kind)
    local requirement = ClassifyAppearanceRequirement(change)
    local refresh
    if element then
        refresh = requirement == "layout" and element.refreshLayout
            or requirement == "appearance" and element.refreshAppearance
    end
    if not refresh and element and element.typedRegistration and not element.skinAdapter then
        refresh = requirement == "layout" and self.RefreshTypedElementLayout
            or self.RefreshTypedElementAppearance
    end
    if not element then return false, "unresolved_element" end
    if requirement == "structural" then return false, "structural_change" end
    if element.requiresStructuralRefresh then return false, "structural_element" end
    if module and module.requiresStructuralRefresh then return false, "structural_module" end
    if not self:IsModuleEnabled(element.module) then return false, "module_disabled" end
    if not sharedType then return false, "unknown_component_type" end
    if not ChangeMatchesSharedType(change, element, sharedType, allowStyleFamily) then
        return false, "style_mismatch"
    end
    if element.skinAdapter and not element.refreshAppearance then
        return false, "custom_adapter"
    end
    if type(refresh) ~= "function" then return false, "missing_refresh_contract" end
    if not refresh(self, element, change) then
        return false, "targeted_refresh_failed"
    end
    return true
end

local function AppearanceScopeIncludes(self, scopeID, ancestorID)
    local chain = GetAppearanceScopeChain(scopeID)
    for i = 1, #(chain or {}) do
        if chain[i] == ancestorID then return true end
    end
    return false
end

local function RefreshWindowAppearance(self, change)
    if type(change.windowID) ~= "string" or change.windowID == "" then
        return false, "unresolved_window"
    end
    local elements, modules, windows = {}, {}, {}
    self:ForEachRegisteredSkinningElement(function(element)
        if AppearanceScopeIncludes(self, element.appearanceWindowID, change.windowID) then
            elements[#elements + 1] = element
            if element.window then windows[element.window] = true end
            local module = self.modules[element.module]
            if module and self:IsModuleEnabled(element.module)
                and type(module.RefreshAppearance) == "function"
            then
                modules[module] = true
            end
        end
    end)

    for module in pairs(modules) do module:RefreshAppearance(change) end
    for i = 1, #elements do
        local element = elements[i]
        local module = self.modules[element.module]
        local sharedType = self:GetSharedElementType(element.kind)
        if not modules[module] and self:IsModuleEnabled(element.module)
            and sharedType
            and ChangeMatchesSharedType(change, element, sharedType, true)
        then
            local refreshed, reason = RefreshElementForChange(
                self, element, change, true)
            if not refreshed and reason ~= "module_disabled" then return false, reason end
        end
    end
    if ClassifyAppearanceRequirement(change) == "layout" then
        for i = 1, #elements do self:ResnapPixelBordersForElement(elements[i]) end
        for window in pairs(windows) do self:ResnapPixelBordersForTarget(window) end
    end
    return true
end

local function RefreshSharedTypeAppearance(self, change)
    local hasStyle = type(change.style) == "string" and change.style ~= ""
    local hasType = type(change.typeID) == "string" and change.typeID ~= ""
    if not hasStyle and not hasType then
        return false, "unresolved_type_style"
    end
    if hasType and not self:GetSharedElementType(change.typeID) then
        return false, "unknown_component_type"
    end
    local matched = false
    local failureReason
    self:ForEachRegisteredSkinningElement(function(element)
        if failureReason then return end
        local sharedType = self:GetSharedElementType(element.kind)
        if sharedType
            and ChangeMatchesSharedType(change, element, sharedType, true)
        then
            matched = true
            local refreshed, reason = RefreshElementForChange(
                self, element, change, true)
            if not refreshed and reason ~= "module_disabled" then failureReason = reason end
        end
    end)
    if failureReason then return false, failureReason end
    -- No registered instance is still a successful scoped update: future
    -- registrations resolve the new shared style when they are created.
    return true, matched
end

function NSkin:RefreshAppearance(change)
    self:InvalidateAppearance(change)

    if change and change.scope == "element" then
        local element = self:GetSkinningElement(change.elementID)
        local refreshed, fallbackReason = RefreshElementForChange(
            self, element, change, false)
        if refreshed then
            if self.RefreshSkinningModeAppearance then
                self:RefreshSkinningModeAppearance(change)
            end
            return
        end
        RecordAppearanceFallback(change, fallbackReason)
    elseif change and change.scope == "window" then
        local refreshed, fallbackReason = RefreshWindowAppearance(self, change)
        if refreshed then
            if self.RefreshSkinningModeAppearance then
                self:RefreshSkinningModeAppearance(change)
            end
            return
        end
        RecordAppearanceFallback(change, fallbackReason)
    elseif change and change.scope == "type" then
        local refreshed, fallbackReason = RefreshSharedTypeAppearance(self, change)
        if refreshed then
            if self.RefreshOptionsAppearance then self:RefreshOptionsAppearance(change) end
            if self.RefreshSkinningModeAppearance then
                self:RefreshSkinningModeAppearance(change)
            end
            return
        end
        RecordAppearanceFallback(change, fallbackReason)
    elseif change then
        RecordAppearanceFallback(change,
            change.scope == "global" and "global_change" or "broad_scope")
    else
        RecordAppearanceFallback(change, "compatibility_refresh")
    end

    if self.RefreshOptionsAppearance then self:RefreshOptionsAppearance() end
    if self.RefreshSkinningModeAppearance then self:RefreshSkinningModeAppearance() end
    for _, module in pairs(self.modules) do
        if self:IsModuleEnabled(module.name) and type(module.RefreshAppearance) == "function" then
            module:RefreshAppearance()
        end
    end
    if self.RefreshRegisteredTabGroups then self:RefreshRegisteredTabGroups() end
    if self.ResnapAllPixelBorders then self:ResnapAllPixelBorders() end
end

local GLOBAL_APPEARANCE_DEPENDENCIES = {
    typography = true,
    accent = true,
    skinningMode = true,
    options = true,
}

GetGlobalAppearanceChangeScope = function(self, styleName)
    if GLOBAL_APPEARANCE_DEPENDENCIES[styleName] then return "global" end
    return self:HasSharedElementStyle(styleName) and "type" or "global"
end

function NSkin:RunWithLiveInspectorAppearanceChange(elementID, callback)
    if type(elementID) ~= "string" or elementID == ""
        or type(callback) ~= "function"
    then
        return false
    end
    local previous = self._liveInspectorAppearanceElementID
    self._liveInspectorAppearanceElementID = elementID
    local ok, result = pcall(callback)
    self._liveInspectorAppearanceElementID = previous
    if not ok then error(result, 0) end
    return result
end

function NSkin:ShouldRefreshSkinningModeInspector(change, selectedElementID)
    if not change or change.scope ~= "element"
        or change.origin ~= "activeInspectorLive"
        or change.elementID ~= selectedElementID
    then
        return true
    end
    return ClassifyAppearanceRequirement(change) == "structural"
end

function NSkin:SetAppearanceOverride(path, value)
    if type(path) ~= "string" or path == "" then return false end
    local defaultValue = GetPath(self.baseAppearance, path, false)
    if defaultValue ~= nil and type(defaultValue) ~= type(value) then return false end

    local profile = self:GetProfile()
    local currentValue = profile.appearance
        and GetPath(profile.appearance, path, false) or nil
    local newValue = defaultValue ~= nil and TablesEqual(value, defaultValue)
        and nil or value
    if TablesEqual(currentValue, newValue) then return false end
    profile.appearance = profile.appearance or {}
    local _, parent, key = GetPath(profile.appearance, path, true)
    parent[key] = newValue
    PruneEmptyTables(profile.appearance)
    if not next(profile.appearance) then profile.appearance = nil end
    local styleName = path:match("^([^.]+)")
    self:RefreshAppearance({
        scope = GetGlobalAppearanceChangeScope(self, styleName),
        style = styleName,
        path = path,
    })
    return true
end

function NSkin:ResetAppearanceOverride(path)
    if type(path) ~= "string" or path == "" then return false end
    local profile = self:GetProfile()
    if not profile.appearance then return false end

    local current, parent, key = GetPath(profile.appearance, path, false)
    if not parent or current == nil then return false end
    parent[key] = nil
    PruneEmptyTables(profile.appearance)
    if not next(profile.appearance) then profile.appearance = nil end
    local styleName = path:match("^([^.]+)")
    self:RefreshAppearance({
        scope = GetGlobalAppearanceChangeScope(self, styleName),
        style = styleName,
        path = path,
    })
    return true
end

end

do
local _, NSkin = ...

local skinData = setmetatable({}, { __mode = "k" })
local pixelBorders = setmetatable({}, { __mode = "k" })
local QueuePixelBorderResnap

function NSkin:GetPhysicalPixelSize(frame)
    local _, physicalHeight
    if _G.GetPhysicalScreenSize then
        _, physicalHeight = _G.GetPhysicalScreenSize()
    end
    physicalHeight = tonumber(physicalHeight) or 768
    local scale = frame and frame.GetEffectiveScale and frame:GetEffectiveScale()
        or (UIParent and UIParent:GetEffectiveScale()) or 1
    if not scale or scale <= 0 then scale = 1 end
    return (768 / math.max(1, physicalHeight)) / scale
end

function NSkin:SnapToPhysicalPixel(frame, value)
    value = tonumber(value) or 0
    local pixel = self:GetPhysicalPixelSize(frame)
    local scaled = value / pixel
    if scaled >= 0 then return math.floor(scaled + 0.5) * pixel end
    return math.ceil(scaled - 0.5) * pixel
end

function NSkin:ConfigureOwnedPixelTexture(texture)
    if not texture then return end
    local data = self:GetSkinData(texture, "ownedPixelTexture")
    if data.configured then return end
    if texture.SetSnapToPixelGrid then texture:SetSnapToPixelGrid(false) end
    if texture.SetTexelSnappingBias then texture:SetTexelSnappingBias(0) end
    data.configured = true
end

local function ColorValuesEqual(color, red, green, blue, alpha)
    return color and color[1] == red and color[2] == green
        and color[3] == blue and color[4] == alpha
end

function NSkin:SetOwnedTextureColor(texture, red, green, blue, alpha)
    if not texture or not texture.SetColorTexture then return false end
    alpha = alpha == nil and 1 or alpha
    local data = self:GetSkinData(texture, "ownedTextureColor")
    if ColorValuesEqual(data.color, red, green, blue, alpha) then return false end
    texture:SetColorTexture(red, green, blue, alpha)
    data.color = { red, green, blue, alpha }
    return true
end

function NSkin:SetFontStringColor(fontString, red, green, blue, alpha)
    if not fontString or not fontString.SetTextColor then return false end
    alpha = alpha == nil and 1 or alpha
    local data = self:GetSkinData(fontString, "ownedFontColor")
    local actualMatches
    if fontString.GetTextColor then
        local currentRed, currentGreen, currentBlue, currentAlpha =
            fontString:GetTextColor()
        actualMatches = currentRed == red and currentGreen == green
            and currentBlue == blue and (currentAlpha or 1) == alpha
    end
    if ColorValuesEqual(data.color, red, green, blue, alpha)
        and actualMatches ~= false
    then
        return false
    end
    fontString:SetTextColor(red, green, blue, alpha)
    data.color = { red, green, blue, alpha }
    return true
end

local function ApplyPixelBorderGeometry(border)
    if not border or not border.anchor then return end
    local anchor = border.anchor
    local pixel = NSkin:GetPhysicalPixelSize(anchor)
    local requestedSize = math.max(1, tonumber(border.requestedSize) or 1)
    local thickness = requestedSize * pixel
    local requestedPadding = tonumber(border.requestedPadding)
    local padding = requestedPadding and requestedPadding * pixel or 0
    border.pixelSize = pixel
    border.effectiveSize = thickness
    border.effectivePadding = padding

    for _, key in ipairs({ "top", "bottom", "left", "right" }) do
        local edge = border[key]
        if edge then
            edge:ClearAllPoints()
            NSkin:ConfigureOwnedPixelTexture(edge)
        end
    end
    if border.outside and requestedPadding == nil then
        if border.top then
            border.top:SetPoint("BOTTOMLEFT", anchor, "TOPLEFT", -thickness, 0)
            border.top:SetPoint("BOTTOMRIGHT", anchor, "TOPRIGHT", thickness, 0)
        end
        if border.bottom then
            border.bottom:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", -thickness, 0)
            border.bottom:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", thickness, 0)
        end
        if border.left then
            border.left:SetPoint("TOPRIGHT", anchor, "TOPLEFT", 0, thickness)
            border.left:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMLEFT", 0, -thickness)
        end
        if border.right then
            border.right:SetPoint("TOPLEFT", anchor, "TOPRIGHT", 0, thickness)
            border.right:SetPoint("BOTTOMLEFT", anchor, "BOTTOMRIGHT", 0, -thickness)
        end
    else
        if border.top then
            border.top:SetPoint("TOPLEFT", anchor, "TOPLEFT", -padding, padding)
            border.top:SetPoint("TOPRIGHT", anchor, "TOPRIGHT", padding, padding)
        end
        if border.bottom then
            border.bottom:SetPoint("BOTTOMLEFT", anchor, "BOTTOMLEFT", -padding, -padding)
            border.bottom:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", padding, -padding)
        end
        if border.left then
            border.left:SetPoint("TOPLEFT", anchor, "TOPLEFT", -padding, padding)
            border.left:SetPoint("BOTTOMLEFT", anchor, "BOTTOMLEFT", -padding, -padding)
        end
        if border.right then
            border.right:SetPoint("TOPRIGHT", anchor, "TOPRIGHT", padding, padding)
            border.right:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", padding, -padding)
        end
    end
    if border.top then border.top:SetHeight(thickness) end
    if border.bottom then border.bottom:SetHeight(thickness) end
    if border.left then border.left:SetWidth(thickness) end
    if border.right then border.right:SetWidth(thickness) end
end

function NSkin:ResnapPixelBorder(border)
    ApplyPixelBorderGeometry(border)
end

function NSkin:ResnapAllPixelBorders()
    for border in pairs(pixelBorders) do ApplyPixelBorderGeometry(border) end
end

local function QueueBorderSetResnap(data)
    if not data or data.pending then return end
    data.pending = true
    local function Resnap()
        data.pending = nil
        for border in pairs(data.borders or {}) do ApplyPixelBorderGeometry(border) end
    end
    if C_Timer and C_Timer.After then C_Timer.After(0, Resnap) else Resnap() end
end

function NSkin:GetSkinData(object, namespace, create)
    if not object then return nil end

    -- Preserve GetSkinData(object, false) while allowing each subsystem to
    -- keep its state in a clearly named table.
    if type(namespace) == "boolean" then
        create = namespace
        namespace = nil
    end

    local data = skinData[object]
    if not data and create ~= false then
        data = {}
        skinData[object] = data
    end
    if not data or not namespace then return data end

    local scoped = data[namespace]
    if not scoped and create ~= false then
        scoped = {}
        data[namespace] = scoped
    end
    return scoped
end

local function TrackPixelBorderOwner(border, frame, anchor)
    local owner = anchor
    if not (owner and owner.IsObjectType and owner:IsObjectType("Frame")) then
        owner = frame
    end
    if not owner then return end
    border.pixelOwner = owner
    local ownerData = NSkin:GetSkinData(owner, "physicalPixels")
    ownerData.borders = ownerData.borders
        or setmetatable({}, { __mode = "k" })
    ownerData.borders[border] = true
    if ownerData.resnapHooked then return end
    ownerData.resnapHooked = true
    if owner.HookScript then
        owner:HookScript("OnSizeChanged", function()
            QueueBorderSetResnap(ownerData)
        end)
        owner:HookScript("OnShow", function()
            QueueBorderSetResnap(ownerData)
        end)
    end
    if _G.hooksecurefunc and owner.SetScale then
        pcall(_G.hooksecurefunc, owner, "SetScale", function()
            QueueBorderSetResnap(ownerData)
        end)
    end
end

function NSkin:ResnapPixelBordersForTarget(target)
    local data = self:GetSkinData(target, "physicalPixels", false)
    if not data or not data.borders or not next(data.borders) then return false end
    QueueBorderSetResnap(data)
    return true
end

function NSkin:GetPixelBorder(frame, key)
    local data = self:GetSkinData(frame, "primitives", false)
    return data and data.borders and data.borders[key]
end

function NSkin:GetFlatBackground(frame, key)
    local data = self:GetSkinData(frame, "primitives", false)
    return data and data.backgrounds and data.backgrounds[key or "NSkinFlatBackground"]
end

-- Creates four simple texture edges without using BackdropTemplate or NineSlice.
-- The regions are owned by the target frame and do not alter protected state.

-- Icons Skinning
function NSkin:CreatePixelBorder(frame, key, size, color, outside, anchor)
    if not frame or not frame.CreateTexture then return nil end
    local data = self:GetSkinData(frame, "primitives")
    if key then
        data.borders = data.borders or {}
        if data.borders[key] then return data.borders[key] end
    end

    size = size or 1
    color = color or self:GetStyle("icon").border
    anchor = anchor or frame

    local function NewEdge()
        local edge = frame:CreateTexture(nil, "OVERLAY", nil, 7)
        self:SetOwnedTextureColor(edge, unpack(color))
        self:ConfigureOwnedPixelTexture(edge)
        return edge
    end

    local top = NewEdge()
    local bottom = NewEdge()
    local left = NewEdge()
    local right = NewEdge()

    local border = { top = top, bottom = bottom, left = left, right = right,
        frame = frame, anchor = anchor, outside = outside == true,
        requestedSize = tonumber(size) or 1,
        color = { color[1], color[2], color[3], color[4] or 1 } }
    pixelBorders[border] = true
    ApplyPixelBorderGeometry(border)
    TrackPixelBorderOwner(border, frame, anchor)
    if key then data.borders[key] = border end
    return border
end

-- Creates only the requested physical-pixel edges. Components that attach to
-- a window edge can therefore omit that seam instead of drawing a full border
-- and covering one side with another region.
function NSkin:CreatePixelEdgeBorder(frame, key, edges, size, color, anchor)
    if not frame or not frame.CreateTexture or type(edges) ~= "table" then
        return nil
    end
    local data = self:GetSkinData(frame, "primitives")
    data.borders = data.borders or {}
    if key and data.borders[key] then return data.borders[key] end

    color = color or self:GetStyle("icon").border
    local border = {
        frame = frame,
        anchor = anchor or frame,
        outside = false,
        requestedSize = tonumber(size) or 1,
    }
    for _, edgeName in ipairs(edges) do
        if (edgeName == "top" or edgeName == "bottom"
            or edgeName == "left" or edgeName == "right")
            and not border[edgeName]
        then
            local edge = frame:CreateTexture(nil, "OVERLAY", nil, 7)
            self:SetOwnedTextureColor(edge, unpack(color))
            self:ConfigureOwnedPixelTexture(edge)
            border[edgeName] = edge
        end
    end
    if not border.top and not border.bottom and not border.left
        and not border.right
    then return nil end

    pixelBorders[border] = true
    border.color = { color[1], color[2], color[3], color[4] or 1 }
    ApplyPixelBorderGeometry(border)
    TrackPixelBorderOwner(border, frame, border.anchor)
    if key then data.borders[key] = border end
    return border
end

function NSkin:SetPixelBorderShown(border, shown)
    if not border or border.shown == shown then return end

    if border.top then border.top:SetShown(shown) end
    if border.bottom then border.bottom:SetShown(shown) end
    if border.left then border.left:SetShown(shown) end
    if border.right then border.right:SetShown(shown) end
    border.shown = shown
end

function NSkin:SetPixelBorderColor(border, red, green, blue, alpha)
    if not border then return end

    alpha = alpha or 1
    if ColorValuesEqual(border.color, red, green, blue, alpha) then return false end
    for _, key in ipairs({ "top", "bottom", "left", "right" }) do
        local edge = border[key]
        if edge then
            self:SetOwnedTextureColor(edge, red, green, blue, alpha)
            self:ConfigureOwnedPixelTexture(edge)
        end
    end
    border.color = { red, green, blue, alpha }
    return true
end

function NSkin:SetPixelBorderSize(border, size)
    if not border or not size then return end
    local requestedSize = tonumber(size) or border.requestedSize or 1
    if border.requestedSize == requestedSize then return false end
    border.requestedSize = requestedSize
    ApplyPixelBorderGeometry(border)
    return true
end

function NSkin:SetPixelBorderPadding(border, padding)
    if not border or not border.anchor then return end
    local requestedPadding = tonumber(padding) or 0
    if border.requestedPadding == requestedPadding then return false end
    border.requestedPadding = requestedPadding
    border.padding = border.requestedPadding
    ApplyPixelBorderGeometry(border)
    return true
end

function NSkin:CreateQualityBorder(frame, anchor, key, size, outside)
    local border = self:CreatePixelBorder(frame, key, size, nil, outside == true, anchor)
    self:SetPixelBorderShown(border, false)
    return border
end

function NSkin:SetQualityBorder(border, quality)
    local item = _G.C_Item
    if not border then return false end
    local style = self:GetStyle("icon")
    local borderColor = style and style.border
        or self:GetComponentBorderColor("icon", style)
    local borderMode = string.lower(tostring(
        style and style.borderMode or "quality"))
    if borderMode ~= "quality" or quality == nil
        or not item or not item.GetItemQualityColor
    then
        self:SetPixelBorderColor(border, unpack(borderColor))
        self:SetPixelBorderShown(border, true)
        return true
    end

    local red, green, blue = item.GetItemQualityColor(quality)
    if not red then
        self:SetPixelBorderColor(border, unpack(borderColor))
        self:SetPixelBorderShown(border, true)
        return true
    end
    self:SetPixelBorderColor(border, red, green, blue)
    self:SetPixelBorderShown(border, true)
    return true
end

function NSkin:HideTextureRegions(frame, textureToKeep)
    if not frame or not frame.GetRegions then return end

    local regions = { frame:GetRegions() }
    for i = 1, #regions do
        local region = regions[i]
        if region ~= textureToKeep and region.GetObjectType
            and region:GetObjectType() == "Texture" then
            -- Blizzard frequently shows these regions again when control
            -- state changes. Alpha remains suppressed across those Show calls.
            region:SetAlpha(0)
            region:SetTexture(nil)
            region:Hide()
        end
    end
end

function NSkin:CreateFlatBackground(frame, key, color, borderColor)
    if not frame or not frame.CreateTexture or not color or not borderColor then return nil end

    key = key or "NSkinFlatBackground"
    local data = self:GetSkinData(frame, "primitives")
    data.backgrounds = data.backgrounds or {}
    local background = data.backgrounds[key]
    if not background then
        background = frame:CreateTexture(nil, "BACKGROUND", nil, 7)
        if not background then return nil end
        background:SetPoint("TOPLEFT", 1, -1)
        background:SetPoint("BOTTOMRIGHT", -1, 1)
        data.backgrounds[key] = background
    end
    self:SetOwnedTextureColor(background, unpack(color))
    self:ConfigureOwnedPixelTexture(background)
    local backgroundState = self:GetSkinData(background, "flatBackground")
    if not backgroundState.shown
        or (background.IsShown and not background:IsShown())
    then
        background:Show()
        backgroundState.shown = true
    end
    local border = self:CreatePixelBorder(frame, key .. "Border", 1, borderColor)
    self:SetPixelBorderColor(border, unpack(borderColor))
    return background
end

local pixelResnapPending = false
QueuePixelBorderResnap = function()
    if pixelResnapPending then return end
    pixelResnapPending = true
    local function Resnap()
        pixelResnapPending = false
        NSkin:ResnapAllPixelBorders()
    end
    if C_Timer and C_Timer.After then C_Timer.After(0, Resnap) else Resnap() end
end

NSkin:RegisterEvent("UI_SCALE_CHANGED", QueuePixelBorderResnap)
NSkin:RegisterEvent("DISPLAY_SIZE_CHANGED", QueuePixelBorderResnap)

end
local _, NSkin = ...

local COMPONENT_STATE = "components"
local COMPONENT_INTERNALS = NSkin._componentInternals or {}
NSkin._componentInternals = COMPONENT_INTERNALS
COMPONENT_INTERNALS.tabGroups = COMPONENT_INTERNALS.tabGroups or {}
COMPONENT_INTERNALS.tabGroupOriginalPoints = COMPONENT_INTERNALS.tabGroupOriginalPoints or {}
COMPONENT_INTERNALS.skinningElements = COMPONENT_INTERNALS.skinningElements or {}
COMPONENT_INTERNALS.componentCallbacks = COMPONENT_INTERNALS.componentCallbacks or {}
COMPONENT_INTERNALS.movableOriginalPoints = COMPONENT_INTERNALS.movableOriginalPoints or {}
COMPONENT_INTERNALS.movableOriginalSizes = COMPONENT_INTERNALS.movableOriginalSizes or {}
COMPONENT_INTERNALS.componentBaselines = COMPONENT_INTERNALS.componentBaselines
    or setmetatable({}, { __mode = "k" })
COMPONENT_INTERNALS.componentBaselineTargets = COMPONENT_INTERNALS.componentBaselineTargets
    or setmetatable({}, { __mode = "v" })
COMPONENT_INTERNALS.movableElementsByWindow = COMPONENT_INTERNALS.movableElementsByWindow
    or setmetatable({}, { __mode = "k" })
COMPONENT_INTERNALS.movableWatchers = COMPONENT_INTERNALS.movableWatchers
    or setmetatable({}, { __mode = "k" })
COMPONENT_INTERNALS.registeredWindows = COMPONENT_INTERNALS.registeredWindows
    or setmetatable({}, { __mode = "k" })
COMPONENT_INTERNALS.windowSequence = COMPONENT_INTERNALS.windowSequence or 0
COMPONENT_INTERNALS.SUPPRESS_NOTIFICATION = COMPONENT_INTERNALS.SUPPRESS_NOTIFICATION
    or { suppressNotify = true }
local tabGroups = COMPONENT_INTERNALS.tabGroups
local tabGroupOriginalPoints = COMPONENT_INTERNALS.tabGroupOriginalPoints
local skinningElements = COMPONENT_INTERNALS.skinningElements
local componentCallbacks = COMPONENT_INTERNALS.componentCallbacks
local movableOriginalPoints = COMPONENT_INTERNALS.movableOriginalPoints
local movableOriginalSizes = COMPONENT_INTERNALS.movableOriginalSizes
local componentBaselines = COMPONENT_INTERNALS.componentBaselines
local componentBaselineTargets = COMPONENT_INTERNALS.componentBaselineTargets
local movableElementsByWindow = COMPONENT_INTERNALS.movableElementsByWindow
local movableWatchers = COMPONENT_INTERNALS.movableWatchers
local registeredWindows = COMPONENT_INTERNALS.registeredWindows
local windowSequence = COMPONENT_INTERNALS.windowSequence
local SUPPRESS_NOTIFICATION = COMPONENT_INTERNALS.SUPPRESS_NOTIFICATION
local GetCurrentWindowPlacement
local function CaptureFramePoints(target)
    local points = {}
    if target and target.GetNumPoints then
        for i = 1, target:GetNumPoints() do
            points[i] = { target:GetPoint(i) }
        end
    end
    return points
end

local function RestoreFramePoints(target, points)
    if not target or not target.ClearAllPoints or type(points) ~= "table" then
        return false
    end
    target:ClearAllPoints()
    for i = 1, #points do target:SetPoint(unpack(points[i])) end
    return true
end

function NSkin:CaptureComponentBaseline(id, target, options)
    if type(id) ~= "string" or id == "" or not target then return nil end
    options = options or {}
    local baselines = componentBaselines[target]
    if not baselines then
        baselines = {}
        componentBaselines[target] = baselines
    end
    local existing = baselines[id]
    if existing and not options.force then return existing end
    if type(options.canCapture) == "function"
        and options.canCapture(target) ~= true
    then return nil end

    local baseline = existing or { modified = {} }
    baseline.id, baseline.target = id, target
    baseline.options = options
    if options.size and target.GetSize then
        baseline.width, baseline.height = target:GetSize()
    end
    if options.points then baseline.points = CaptureFramePoints(target) end
    local fontString = options.font == true and target or options.font
    if fontString and fontString.GetFont then
        baseline.fontTarget = fontString
        baseline.font = { fontString:GetFont() }
    end
    local editBox = options.textInsets == true and target or options.textInsets
    if editBox and editBox.GetTextInsets then
        baseline.textInsetsTarget = editBox
        baseline.textInsets = { editBox:GetTextInsets() }
    end
    local texture = options.texCoords == true and target or options.texCoords
    if texture and texture.GetTexCoord then
        baseline.texCoordTarget = texture
        baseline.texCoords = { texture:GetTexCoord() }
    end
    local spacingTarget = options.spacing == true and target or options.spacing
    if spacingTarget then
        baseline.spacingTarget = spacingTarget
        baseline.spacing = spacingTarget.spacing
    end
    baseline.refreshBlizzardLayout = options.refreshBlizzardLayout
    baselines[id] = baseline
    componentBaselineTargets[id] = target
    return baseline
end

function NSkin:GetComponentBaseline(idOrTarget)
    if type(idOrTarget) == "string" then
        local target = componentBaselineTargets[idOrTarget]
        local baselines = target and componentBaselines[target]
        return baselines and baselines[idOrTarget] or nil
    end
    local baselines = idOrTarget and componentBaselines[idOrTarget]
    if not baselines then return nil end
    for _, baseline in pairs(baselines) do return baseline end
end

function NSkin:MarkComponentGeometryModified(idOrTarget, property, modified)
    local baseline = self:GetComponentBaseline(idOrTarget)
    if not baseline then return false end
    baseline.modified[property] = modified ~= false or nil
    return true
end

function NSkin:RestoreComponentBaseline(idOrTarget, properties)
    local baseline = self:GetComponentBaseline(idOrTarget)
    if not baseline then return false end
    if type(baseline.refreshBlizzardLayout) == "function" then
        if baseline.refreshBlizzardLayout(baseline) == true then
            wipe(baseline.modified)
            local options = baseline.options or {}
            options.force = true
            self:CaptureComponentBaseline(
                baseline.id, baseline.target, options)
            options.force = nil
            return true
        end
    end
    local requested = type(properties) == "table" and properties or nil
    local function ShouldRestore(key)
        return (not requested or requested[key]) and baseline.modified[key]
    end
    local target = baseline.target
    if ShouldRestore("size") and target.SetSize
        and baseline.width and baseline.height
    then target:SetSize(baseline.width, baseline.height) end
    if ShouldRestore("points") then RestoreFramePoints(target, baseline.points) end
    if ShouldRestore("font") and baseline.fontTarget and baseline.font then
        baseline.fontTarget:SetFont(unpack(baseline.font))
    end
    if ShouldRestore("textInsets") and baseline.textInsetsTarget
        and baseline.textInsets
    then baseline.textInsetsTarget:SetTextInsets(unpack(baseline.textInsets)) end
    if ShouldRestore("texCoords") and baseline.texCoordTarget
        and baseline.texCoords and baseline.texCoordTarget.SetTexCoord
    then baseline.texCoordTarget:SetTexCoord(unpack(baseline.texCoords)) end
    if ShouldRestore("spacing") and baseline.spacingTarget then
        baseline.spacingTarget.spacing = baseline.spacing
        if baseline.spacingTarget.MarkDirty then baseline.spacingTarget:MarkDirty() end
    end
    for key in pairs(baseline.modified) do
        if not requested or requested[key] then baseline.modified[key] = nil end
    end
    return true
end

function NSkin:RefreshComponentBaseline(idOrTarget)
    local baseline = self:GetComponentBaseline(idOrTarget)
    if not baseline or next(baseline.modified) then return false end
    local options = baseline.options or {}
    options.force = true
    self:CaptureComponentBaseline(baseline.id, baseline.target, options)
    options.force = nil
    return true
end

local function CopyPlacement(placement)
    local copy = {}
    for key, value in pairs(placement or {}) do copy[key] = value end
    return copy
end

function NSkin:RegisterComponentCallback(event, callback, owner)
    if type(event) ~= "string" or type(callback) ~= "function" then return false end
    local listeners = componentCallbacks[event]
    if not listeners then
        listeners = {}
        componentCallbacks[event] = listeners
    end
    listeners[#listeners + 1] = { callback = callback, owner = owner }
    return true
end

function NSkin:UnregisterComponentCallbacks(owner)
    if owner == nil then return false end
    for _, listeners in pairs(componentCallbacks) do
        for i = #listeners, 1, -1 do
            if listeners[i].owner == owner then table.remove(listeners, i) end
        end
    end
    return true
end

local function FireComponentCallback(event, ...)
    local listeners = componentCallbacks[event]
    if not listeners then return end
    for i = 1, #listeners do
        local listener = listeners[i]
        listener.callback(listener.owner, ...)
    end
end

function NSkin:CreateOptionsSlider(parent, options)
    if not parent then return nil end
    options = options or {}
    local slider = CreateFrame("Slider", nil, parent)
    slider:SetSize(options.width or 280, options.height or 18)
    slider:SetOrientation("HORIZONTAL")
    slider:SetMinMaxValues(options.min or 0, options.max or 100)
    slider:SetValueStep(options.step or 1)
    slider:SetObeyStepOnDrag(options.obeyStep ~= false)
    local track = slider:CreateTexture(nil, "BACKGROUND")
    track:SetPoint("LEFT", slider, "LEFT", 0, 0)
    track:SetPoint("RIGHT", slider, "RIGHT", 0, 0)
    track:SetHeight(4)
    track:SetColorTexture(0.35, 0.35, 0.35, 1)

    local accent = self:GetAccentColor()
    local fillGlows = {}
    local glowHeights = { 12, 8, 4 }
    local glowAlphas = { 0.10, 0.18, 0.34 }
    for i = 1, 3 do
        local glow = slider:CreateTexture(nil, "ARTWORK", nil, -2 + i)
        glow:SetPoint("LEFT", slider, "LEFT", 0, 0)
        glow:SetHeight(glowHeights[i])
        glow:SetBlendMode("ADD")
        glow:SetColorTexture(accent[1], accent[2], accent[3], glowAlphas[i])
        fillGlows[i] = glow
    end

    local fill = slider:CreateTexture(nil, "ARTWORK")
    fill:SetPoint("LEFT", slider, "LEFT", 0, 0)
    fill:SetHeight(4)
    fill:SetColorTexture(unpack(accent))

    slider:SetThumbTexture("Interface\\Buttons\\WHITE8X8")
    local marker = slider:GetThumbTexture()
    marker:SetSize(3, 14)
    marker:SetColorTexture(unpack(accent))
    local markerGlowOuter = slider:CreateTexture(nil, "ARTWORK")
    markerGlowOuter:SetPoint("CENTER", marker, "CENTER", 0, 0)
    markerGlowOuter:SetSize(7, 17)
    markerGlowOuter:SetBlendMode("ADD")
    markerGlowOuter:SetColorTexture(accent[1], accent[2], accent[3], 0.12)
    local markerGlowInner = slider:CreateTexture(nil, "ARTWORK", nil, 1)
    markerGlowInner:SetPoint("CENTER", marker, "CENTER", 0, 0)
    markerGlowInner:SetSize(3, 13)
    markerGlowInner:SetBlendMode("ADD")
    markerGlowInner:SetColorTexture(accent[1], accent[2], accent[3], 0.30)

    local minimum, maximum = options.min or 0, options.max or 100
    local function RefreshSliderVisual(value)
        local range = maximum - minimum
        local ratio = range > 0 and math.max(0, math.min(1,
            ((tonumber(value) or minimum) - minimum) / range)) or 0
        local width = math.max(0.001, slider:GetWidth() * ratio)
        fill:SetWidth(width)
        for i = 1, 3 do fillGlows[i]:SetWidth(width) end
    end
    local function RefreshSlider(_, value)
        RefreshSliderVisual(value)
        if type(options.onValueChanged) == "function" then
            options.onValueChanged(slider, value)
        end
    end
    slider:SetScript("OnValueChanged", RefreshSlider)
    RefreshSliderVisual(slider:GetValue())
    return slider
end

-- Buttons Skinning
local EDITOR_PRESETS = {
    WINDOW = {
        { id = "shared.windowSurfaceAppearance", label = "Window Surface",
            presentation = "INLINE", category = "CUSTOMIZE" },
        { id = "shared.windowHeaderAppearance", label = "Header",
            category = "CUSTOMIZE" },
    },
    WINDOW_HEADER_CONTROLS = {
        { id = "shared.windowHeaderControlsAppearance",
            label = "Header Buttons", category = "CUSTOMIZE" },
    },
    TAB_GROUP = {
        { id = "tabs.layout", label = "Position",
            presentation = "INLINE", category = "POSITION" },
        { id = "shared.tabSurfaceAppearance", label = "Tab Surface",
            presentation = "INLINE", category = "CUSTOMIZE" },
        { id = "shared.tabTextAppearance", label = "Tab Text",
            category = "CUSTOMIZE" },
    },
    SIDE_TAB = {
        { id = "shared.movable", label = "Position",
            presentation = "INLINE", category = "POSITION" },
        { id = "shared.sideTabAppearance", label = "Side Tab",
            presentation = "INLINE", category = "CUSTOMIZE" },
    },
    EDIT_BOX = {
        { id = "shared.movable", label = "Position",
            presentation = "INLINE", category = "POSITION" },
        { id = "shared.editBoxAppearance", label = "Edit Box",
            presentation = "INLINE", category = "CUSTOMIZE" },
    },
    SEARCH_GROUP = {
        { id = "shared.searchPosition", label = "Position",
            presentation = "INLINE", category = "POSITION" },
        { id = "shared.searchBoxAppearance", label = "Search Box",
            presentation = "INLINE", category = "CUSTOMIZE" },
        { id = "shared.searchTextAppearance", label = "Search Text",
            category = "CUSTOMIZE" },
        { id = "shared.placeholderTextAppearance", label = "Placeholder Text",
            category = "CUSTOMIZE" },
    },
    SEARCH_ACCESSORY = {
        { id = "shared.movable", label = "Position",
            presentation = "INLINE", category = "POSITION" },
    },
    PAGINATION_GROUP = {
        { id = "shared.paginationPosition", label = "Position",
            presentation = "INLINE", category = "POSITION" },
        { id = "shared.paginationLayout", label = "Layout",
            presentation = "INLINE", category = "LAYOUT" },
    },
    PAGINATION_CHILD = {
        { id = "shared.paginationPosition", label = "Position",
            presentation = "INLINE", category = "POSITION" },
        { id = "shared.paginationLayout", label = "Layout",
            presentation = "INLINE", category = "LAYOUT" },
    },
    SECTION_HEADERS = {
        { id = "shared.sectionHeaderPlacement", label = "Offset",
            presentation = "INLINE", category = "POSITION" },
        { id = "shared.headerTextAppearance", label = "Header Text",
            category = "CUSTOMIZE" },
        { id = "shared.headerUnderlineAppearance", label = "Underline",
            category = "CUSTOMIZE" },
    },
    SECTION_CARD = {
        { id = "shared.movable", label = "Position",
            presentation = "INLINE", category = "POSITION" },
        { id = "shared.sectionCardAppearance", label = "Section Card",
            category = "CUSTOMIZE" },
    },
    COLUMN_HEADER = {
        { id = "shared.columnHeaderAppearance", label = "Column Header",
            category = "CUSTOMIZE" },
    },
    ROW = {
        { id = "shared.rowAppearance", label = "Row",
            category = "CUSTOMIZE" },
    },
    MOVABLE = {
        { id = "shared.movable", label = "Position",
            presentation = "INLINE", category = "POSITION" },
    },
    SCROLLBAR = {
        { id = "shared.movable", label = "Position",
            presentation = "INLINE", category = "POSITION" },
        { id = "shared.scrollBarAppearance", label = "Scrollbar",
            category = "CUSTOMIZE" },
    },
    ICON = {
        { id = "shared.movable", label = "Position",
            presentation = "INLINE", category = "POSITION" },
        { id = "shared.iconAppearance", label = "Icon",
            presentation = "INLINE", category = "CUSTOMIZE" },
    },
    TEXT = {
        { id = "shared.textAppearance", label = "Text",
            category = "CUSTOMIZE" },
    },
}

local SHARED_ELEMENT_TYPES = {}

function NSkin:RegisterSharedElementType(typeID, definition)
    if type(typeID) ~= "string" or typeID == ""
        or type(definition) ~= "table" or SHARED_ELEMENT_TYPES[typeID]
    then return false end
    local preset = definition.editorPreset or typeID
    if not EDITOR_PRESETS[preset] then return false end
    definition.id = typeID
    definition.editorPreset = preset
    SHARED_ELEMENT_TYPES[typeID] = definition
    return true
end

function NSkin:GetSharedElementType(typeID)
    return SHARED_ELEMENT_TYPES[typeID]
end

function NSkin:HasSharedElementStyle(styleName)
    if type(styleName) ~= "string" or styleName == "" then return false end
    for _, definition in pairs(SHARED_ELEMENT_TYPES) do
        local elementStyle = definition.style
        if type(elementStyle) == "string" and (elementStyle == styleName
            or elementStyle:sub(1, #styleName + 1) == styleName .. ".")
        then
            return true
        end
    end
    return false
end

function NSkin:CreateSharedElementEditorOptions(typeID, extras)
    local definition = SHARED_ELEMENT_TYPES[typeID]
    return definition and self:CreateEditorOptionsPreset(
        definition.editorPreset, extras) or nil
end

local function CopyEditorOption(option)
    local copy = {}
    for key, value in pairs(option or {}) do copy[key] = value end
    return copy
end

function NSkin:CreateEditorOptionsPreset(preset, extraEditorOptions)
    local standard = EDITOR_PRESETS[preset] or {}
    local before, after = {}, {}
    for i = 1, #(extraEditorOptions or {}) do
        local option = CopyEditorOption(extraEditorOptions[i])
        local isLayout = option.category == "POSITION"
            or option.category == "LAYOUT"
        local destination = isLayout and before or after
        destination[#destination + 1] = option
    end
    local result = {}
    for i = 1, #before do result[#result + 1] = before[i] end
    for i = 1, #standard do
        result[#result + 1] = CopyEditorOption(standard[i])
    end
    for i = 1, #after do result[#result + 1] = after[i] end
    return result
end

local SHARED_TYPE_DEFINITIONS = {
    WINDOW = { style = "window", skin = "SkinWindow",
        appearanceControls = "shared.windowAppearance" },
    WINDOW_HEADER = { style = "window.header", skin = "SkinWindowHeader",
        appearanceControls = "shared.windowHeaderAppearance", editorPreset = "WINDOW" },
    WINDOW_HEADER_CONTROLS = { style = "windowHeaderButton",
        skin = "SkinWindowHeaderButton",
        appearanceControls = "shared.windowHeaderControlsAppearance" },
    TAB_GROUP = { style = "tab", skin = "SkinTab",
        appearanceControls = "shared.tabAppearance" },
    SIDE_TAB = { style = "sideTab", skin = "SkinSideTab",
        appearanceControls = "shared.sideTabAppearance",
        editorPreset = "SIDE_TAB" },
    BUTTON = { style = "button", skin = "SkinFlatButton", editorPreset = "MOVABLE" },
    ACTION_BUTTON = { style = "button", skin = "SkinActionButton",
        editorPreset = "MOVABLE" },
    CHECKBOX = { style = "button", skin = "SkinCheckButton",
        editorPreset = "MOVABLE" },
    DROPDOWN = { style = "button", skin = "SkinDropdown", editorPreset = "MOVABLE" },
    NAVIGATION_BAR = { style = "navigationBar", skin = "SkinNavigationBar",
        editorPreset = "MOVABLE" },
    EDIT_BOX = { style = "editBox", skin = "SkinEditBox" },
    SEARCH_GROUP = { style = "searchBox", skin = "SkinSearchBox" },
    SEARCH_ACCESSORY = { style = "button", skin = "SkinDropdown" },
    PAGINATION_GROUP = { style = "button", skin = "SkinPagingControls" },
    PAGINATION_CHILD = { style = "button", skin = "SkinFlatButton" },
    PROGRESS_BAR = { style = "progressBar", skin = "SkinProgressBar",
        editorPreset = "MOVABLE" },
    ICON = { style = "icon", skin = "SkinIcon", editorPreset = "ICON",
        preserveAnchorSpan = true },
    SCROLLBAR = { style = "scrollBar", skin = "SkinScrollBar",
        editorPreset = "SCROLLBAR", preserveAnchorSpan = true },
    SECTION_HEADER = { style = "sectionHeader", editorPreset = "SECTION_HEADERS" },
    SECTION_HEADERS = { style = "sectionHeader", editorPreset = "SECTION_HEADERS" },
    SECTION_CARD = { style = "sectionCard", skin = "SkinSectionCard",
        appearanceControls = "shared.sectionCardAppearance",
        editorPreset = "SECTION_CARD" },
    COLUMN_HEADER = { style = "columnHeader", skin = "SkinColumnHeader",
        appearanceControls = "shared.columnHeaderAppearance",
        editorPreset = "COLUMN_HEADER" },
    ROW = { style = "row", skin = "SkinRow",
        appearanceControls = "shared.rowAppearance", editorPreset = "ROW" },
    TEXT = { style = "text", skin = "SkinText",
        appearanceControls = "shared.textAppearance", editorPreset = "TEXT" },
}
for typeID, definition in pairs(SHARED_TYPE_DEFINITIONS) do
    NSkin:RegisterSharedElementType(typeID, definition)
end

function NSkin:RegisterSkinningElement(elementID, definition)
    if type(elementID) ~= "string" or elementID == ""
        or type(definition) ~= "table"
        or not (definition.window or definition.owner)
    then
        return false
    end

    definition.window = definition.window or definition.owner
    definition.target = definition.target or definition.container or definition.owner
    if definition.kind == "WINDOW" and not definition.refreshAppearance
        and type(self.RefreshStandardWindowChromeElement) == "function"
    then
        definition.refreshAppearance = function(_, element)
            return NSkin:RefreshStandardWindowChromeElement(element)
        end
        definition.refreshLayout = function(_, element)
            if not NSkin:RefreshStandardWindowChromeElement(element) then return false end
            local saved = NSkin:GetSavedMovableElementPlacement(element.id)
            if saved and element.applyPlacement then
                element.applyPlacement(element, saved, { suppressNotify = true })
            end
            NSkin:NotifySkinningElementBoundsChanged(element.id)
            return true
        end
    end
    if not definition.typedRegistration and not definition.skinAdapter
        and not definition.refreshAppearance
        and self:GetSharedElementType(definition.kind)
    then
        definition.refreshAppearance = function(_, element)
            if not NSkin:SkinTypedElement(element.kind, element) then return false end
            return true
        end
        definition.refreshLayout = function(owner, element)
            if not element.refreshAppearance(owner, element) then return false end
            local saved = NSkin:GetSavedMovableElementPlacement(element.id)
            if saved and element.applyPlacement
                and NSkin:IsSkinningElementEditable(element)
            then
                element.applyPlacement(element, saved, { suppressNotify = true })
            end
            NSkin:NotifySkinningElementBoundsChanged(element.id)
            NSkin:ResnapPixelBordersForElement(element)
            return true
        end
    end
    if type(definition.appearanceWindowID) ~= "string"
        or definition.appearanceWindowID == ""
        or not self:GetAppearanceScope(definition.appearanceWindowID)
    then
        return false
    end
    if not definition.editorOptions and EDITOR_PRESETS[definition.kind] then
        definition.editorOptions = self:CreateEditorOptionsPreset(
            definition.kind, definition.extraEditorOptions)
    end
    definition.owner = nil
    definition.priority = tonumber(definition.priority) or 0
    definition.highlightPadding = tonumber(definition.highlightPadding) or 0
    if type(definition.baseline) == "table" and definition.target then
        self:CaptureComponentBaseline(elementID, definition.target,
            definition.baseline)
    end
    definition.captureBaseline = definition.captureBaseline or function(element)
        if type(element.baseline) ~= "table" then return false end
        return NSkin:CaptureComponentBaseline(
            element.id, element.target, element.baseline) ~= nil
    end
    definition.restoreGeometry = definition.restoreGeometry or function(element)
        return NSkin:RestoreComponentBaseline(element.id)
    end
    definition.refreshBaseline = definition.refreshBaseline or function(element)
        return NSkin:RefreshComponentBaseline(element.id)
    end
    if not registeredWindows[definition.window] then
        windowSequence = windowSequence + 1
        registeredWindows[definition.window] = windowSequence
    end

    local element = skinningElements[elementID]
    if element then
        for key, value in pairs(definition) do element[key] = value end
    else
        element = definition
        element.id = elementID
        skinningElements[elementID] = element
    end
    FireComponentCallback("SkinningElementRegistered", element)
    return true
end

function NSkin:MarkSkinningWindowActive(window)
    if not window then return false end
    windowSequence = windowSequence + 1
    registeredWindows[window] = windowSequence
    return true
end

function NSkin:GetMostRecentVisibleSkinningWindow(excludedWindow)
    local bestWindow, bestSequence
    for window, sequence in pairs(registeredWindows) do
        if window ~= excludedWindow and window.IsShown and window:IsShown()
            and (not bestSequence or sequence > bestSequence)
        then
            bestWindow, bestSequence = window, sequence
        end
    end
    return bestWindow
end

function NSkin:ForEachRegisteredSkinningElement(callback)
    if type(callback) ~= "function" then return end
    for _, element in pairs(skinningElements) do callback(element) end
end

function NSkin:GetSkinningElement(elementID)
    return skinningElements[elementID]
end

function NSkin:IsSkinningElementEditable(element)
    if not element then return false end
    return type(element.isEditable) ~= "function" or element.isEditable(element) == true
end

function NSkin:LayoutWindowElement(element, placement, options)
    local target = element and element.target
    local window = element and element.window
    if not target or not window or type(placement) ~= "table"
        or not target.ClearAllPoints or not target.SetPoint
        or (target.IsProtected and target:IsProtected())
        or (_G.InCombatLockdown and _G.InCombatLockdown())
    then
        return false
    end
    if placement.mode == "GRID" then
        target:ClearAllPoints()
        target:SetPoint(placement.point or "TOPLEFT", window,
            placement.relativePoint or "TOPLEFT", tonumber(placement.x) or 0,
            tonumber(placement.y) or 0)
        if not (options and options.suppressNotify) then
            self:NotifySkinningElementBoundsChanged(element.id)
        end
        return true
    end
    local relativeElement = placement.relativeTo and skinningElements[placement.relativeTo]
    if relativeElement and relativeElement.snapTarget and relativeElement.window == window
        and relativeElement.target and (not relativeElement.target.IsShown
            or relativeElement.target:IsShown())
    then
        target:ClearAllPoints()
        target:SetPoint(placement.point, relativeElement.target, placement.relativePoint,
            tonumber(placement.offsetX) or 0, tonumber(placement.offsetY) or 0)
        if not (options and options.suppressNotify) then
            self:NotifySkinningElementBoundsChanged(element.id)
        end
        return true
    end
    local edge = placement.edge
    local side = placement.side
    local alignment = placement.alignment
    if (edge ~= "TOP" and edge ~= "BOTTOM")
        or (side ~= "INSIDE" and side ~= "OUTSIDE")
        or (alignment ~= "LEFT" and alignment ~= "CENTER" and alignment ~= "RIGHT")
    then return false end
    local point
    if edge == "TOP" then point = side == "INSIDE" and "TOP" or "BOTTOM"
    else point = side == "INSIDE" and "BOTTOM" or "TOP" end
    local relativePoint = edge
    if alignment ~= "CENTER" then
        point = point .. alignment
        relativePoint = relativePoint .. alignment
    end
    target:ClearAllPoints()
    target:SetPoint(point, window, relativePoint,
        tonumber(placement.alongOffset) or 0, tonumber(placement.edgeOffset) or 0)
    if not (options and options.suppressNotify) then
        self:NotifySkinningElementBoundsChanged(element.id)
    end
    return true
end

-- Scrollbars commonly use both TOP and BOTTOM anchors so their parent owns
-- their height. Replacing that pair with one movable anchor changes the
-- resolved height. Translate the complete captured anchor set instead.
function NSkin:LayoutWindowElementPreservingAnchorSpan(element, placement, options)
    local target = element and element.target
    local window = element and element.window
    if not target or not window or type(placement) ~= "table"
        or (target.IsProtected and target:IsProtected())
        or (_G.InCombatLockdown and _G.InCombatLockdown())
    then return false end

    local baseline = self:GetComponentBaseline(element.id)
    if not baseline or type(baseline.points) ~= "table"
        or #baseline.points < 2
    then return self:LayoutWindowElement(element, placement, options) end

    RestoreFramePoints(target, baseline.points)
    local windowLeft, windowTop = window:GetLeft(), window:GetTop()
    local targetLeft, targetTop = target:GetLeft(), target:GetTop()
    local width, height = target:GetWidth(), target:GetHeight()
    local windowWidth, windowHeight = window:GetWidth(), window:GetHeight()
    if not windowLeft or not windowTop or not targetLeft or not targetTop
        or not width or not height or not windowWidth or not windowHeight
    then return false end

    local desiredX, desiredY
    if placement.mode == "GRID" then
        desiredX = tonumber(placement.x) or 0
        desiredY = tonumber(placement.y) or 0
    elseif not placement.relativeTo then
        local alignment, edge, side = placement.alignment,
            placement.edge, placement.side
        local along = tonumber(placement.alongOffset) or 0
        local edgeOffset = tonumber(placement.edgeOffset) or 0
        if alignment == "LEFT" then
            desiredX = along
        elseif alignment == "CENTER" then
            desiredX = along + windowWidth / 2 - width / 2
        elseif alignment == "RIGHT" then
            desiredX = along + windowWidth - width
        end
        if edge == "TOP" then
            desiredY = side == "INSIDE" and edgeOffset
                or edgeOffset + height
        elseif edge == "BOTTOM" then
            desiredY = side == "INSIDE"
                and edgeOffset + height - windowHeight
                or edgeOffset - windowHeight
        end
    end
    if desiredX == nil or desiredY == nil then return false end

    local deltaX = desiredX - (targetLeft - windowLeft)
    local deltaY = desiredY - (targetTop - windowTop)
    target:ClearAllPoints()
    for i = 1, #baseline.points do
        local point = baseline.points[i]
        target:SetPoint(point[1], point[2], point[3],
            (tonumber(point[4]) or 0) + deltaX,
            (tonumber(point[5]) or 0) + deltaY)
    end
    if not (options and options.suppressNotify) then
        self:NotifySkinningElementBoundsChanged(element.id)
    end
    return true
end

local function GetSavedMovablePlacement(element)
    local options = NSkin:GetModuleOptions(element.module, false)
    return options and options.movablePlacements
        and options.movablePlacements[element.id]
end

local function EnsureMovableWatcher(window)
    local watcher = movableWatchers[window]
    if not watcher then
        watcher = CreateFrame("Frame", nil, window)
        watcher:Hide()
        watcher:SetScript("OnShow", function()
            local elements = movableElementsByWindow[window]
            for i = 1, #(elements or {}) do
                local element = elements[i]
                local placement = GetSavedMovablePlacement(element)
                if placement and NSkin:IsSkinningElementEditable(element) then
                    element.applyPlacement(element, placement)
                end
            end
        end)
        movableWatchers[window] = watcher
    end
    watcher:Show()
end

function NSkin:GetSavedMovableElementPlacement(elementID)
    local element = skinningElements[elementID]
    local placement = element and element.module and GetSavedMovablePlacement(element)
    return placement and CopyPlacement(placement) or nil
end

function NSkin:RestoreMovableElementOriginal(elementOrID, suppressNotify)
    local element = type(elementOrID) == "table"
        and elementOrID or skinningElements[elementOrID]
    if not element or not element.target then return false end
    local restored = self:RestoreComponentBaseline(element.id)
    if not restored then
        local points = movableOriginalPoints[element.id]
        if not points then return false end
        RestoreFramePoints(element.target, points)
        local size = movableOriginalSizes[element.id]
        if size and element.supportsResize and element.target.SetSize then
            element.target:SetSize(size[1], size[2])
        end
    end
    if not suppressNotify then self:NotifySkinningElementBoundsChanged(element.id) end
    return true
end

local function ClearSavedMovablePlacement(element)
    local options = element and NSkin:GetModuleOptions(element.module, false)
    if not options or not options.movablePlacements then return false end
    if options.movablePlacements[element.id] == nil then return false end
    options.movablePlacements[element.id] = nil
    if not next(options.movablePlacements) then options.movablePlacements = nil end
    if not next(options) then
        local profile = NSkin:GetProfile()
        if profile.moduleOptions then
            profile.moduleOptions[element.module] = nil
            if not next(profile.moduleOptions) then profile.moduleOptions = nil end
        end
    end
    return true
end

function NSkin:RegisterMovableElement(definition)
    if type(definition) ~= "table" or type(definition.id) ~= "string"
        or type(definition.module) ~= "string" or not definition.window
        or type(definition.appearanceWindowID) ~= "string"
        or definition.appearanceWindowID == ""
        or not self:GetAppearanceScope(definition.appearanceWindowID)
        or not definition.target
    then return false end
    local id = definition.id
    self:CaptureComponentBaseline(id, definition.target, {
        points = true,
        size = definition.supportsResize == true,
        refreshBlizzardLayout = definition.refreshBlizzardLayout,
        canCapture = definition.canCaptureBaseline,
    })
    if not movableOriginalPoints[id] then
        local points = {}
        for i = 1, definition.target:GetNumPoints() do
            points[i] = { definition.target:GetPoint(i) }
        end
        movableOriginalPoints[id] = points
        if definition.supportsResize and definition.target.GetSize then
            movableOriginalSizes[id] = { definition.target:GetSize() }
        end
    end
    local customApply = definition.applyPlacement
    definition.kind = definition.kind or "MOVABLE"
    local sharedType = self:GetSharedElementType(definition.kind)
    if definition.preserveAnchorSpan == nil and sharedType then
        definition.preserveAnchorSpan = sharedType.preserveAnchorSpan
    end
    if not definition.editorOptions then
        definition.editorOptions = self:CreateEditorOptionsPreset(
            definition.editorPreset
                or (sharedType and sharedType.editorPreset)
                or definition.kind,
            definition.extraEditorOptions)
    end
    definition.draggable = definition.draggable ~= false
    definition.movable = true
    definition.getPlacement = definition.getPlacement or function(element)
        local saved = GetSavedMovablePlacement(element)
        if saved then return CopyPlacement(saved) end
        return CopyPlacement(element.defaultPlacement
            or GetCurrentWindowPlacement(element.window, element.target))
    end
    definition.applyPlacement = customApply or function(element, placement, applyOptions)
        if element.preserveAnchorSpan then
            return NSkin:LayoutWindowElementPreservingAnchorSpan(
                element, placement, applyOptions)
        end
        return NSkin:LayoutWindowElement(element, placement, applyOptions)
    end
    definition.setPlacement = definition.setPlacement or function(element, placement)
        if placement.relativeTo
            and NSkin:WouldCreateSkinningPlacementCycle(element.id, placement.relativeTo)
        then return false end
        if not element.applyPlacement(element, placement) then return false end
        local options = NSkin:GetModuleOptions(element.module, true)
        options.movablePlacements = options.movablePlacements or {}
        options.movablePlacements[element.id] = CopyPlacement(placement)
        NSkin:MarkComponentGeometryModified(element.id, "points", true)
        EnsureMovableWatcher(element.window)
        return true
    end
    definition.resetPlacement = definition.resetPlacement or function(element)
        if not NSkin:RestoreMovableElementOriginal(element) then return false end
        ClearSavedMovablePlacement(element)
        return true
    end
    self:RegisterSkinningElement(id, definition)
    local element = skinningElements[id]
    local elements = movableElementsByWindow[element.window]
    if not elements then
        elements = {}
        movableElementsByWindow[element.window] = elements
    end
    local alreadyRegistered
    for i = 1, #elements do
        if elements[i] == element then alreadyRegistered = true break end
    end
    if not alreadyRegistered then elements[#elements + 1] = element end
    local saved = GetSavedMovablePlacement(element)
    if saved and self:IsSkinningElementEditable(element) then
        if element.applyPlacement(element, saved) then
            self:MarkComponentGeometryModified(element.id, "points", true)
            EnsureMovableWatcher(element.window)
        end
    end
    return true
end

local PROGRESS_COMPONENT_STATE = "progressBarComponent"
local PROGRESS_BACKGROUND_KEY = "NSkinProgressBarBackground"

GetCurrentWindowPlacement = function(window, target)
    local windowLeft, windowTop = window:GetLeft(), window:GetTop()
    local targetLeft, targetTop = target:GetLeft(), target:GetTop()
    if windowLeft and windowTop and targetLeft and targetTop then
        return { mode = "GRID", point = "TOPLEFT", relativePoint = "TOPLEFT",
            x = targetLeft - windowLeft, y = targetTop - windowTop }
    end
    return { edge = "TOP", side = "INSIDE", alignment = "CENTER",
        alongOffset = 0, edgeOffset = -46 }
end

function NSkin:GetCurrentWindowElementPlacement(window, target)
    if not window or not target then return nil end
    return CopyPlacement(GetCurrentWindowPlacement(window, target))
end

function NSkin:RegisterSimpleMovableElement(definition)
    if type(definition) ~= "table" then return nil end
    local existing = definition.id and self:GetSkinningElement(definition.id)
    if existing then
        local saved = self:GetSavedMovableElementPlacement(definition.id)
        if saved and self:IsSkinningElementEditable(existing) then
            existing.applyPlacement(existing, saved, SUPPRESS_NOTIFICATION)
        end
        self:NotifySkinningElementBoundsChanged(definition.id)
        return existing
    end
    if not self:RegisterMovableElement(definition) then return nil end
    return self:GetSkinningElement(definition.id)
end

local SHARED_SKIN_ADAPTERS = {
    COLUMN_HEADER = function(self, skinMethod, target, style, borderColor,
        definition)
        local options = {}
        for key, value in pairs(definition.skinOptions or {}) do
            options[key] = value
        end
        options.style = style
        if options.border == nil then options.border = borderColor end
        for _, key in ipairs({
            "textRegion", "artworkRegions", "preserveTextures",
            "hoverRegion", "getHovered", "visualRegion",
        }) do
            if options[key] == nil then options[key] = definition[key] end
        end
        skinMethod(self, target, options)
    end,
    ROW = function(self, skinMethod, target, style, borderColor, definition)
        local options = {}
        for key, value in pairs(definition.skinOptions or {}) do
            options[key] = value
        end
        options.style = style
        if options.border == nil then options.border = borderColor end
        for _, key in ipairs({
            "nativeDecorationRegions", "artworkRegions", "preserveTextures", "hoverRegion",
            "selectedRegion", "getHovered", "getSelected", "visualRegion",
            "contentRegions", "contentStyle", "height", "reset",
        }) do
            if options[key] == nil then options[key] = definition[key] end
        end
        skinMethod(self, target, options)
    end,
    SECTION_CARD = function(self, skinMethod, target, style, borderColor,
        definition)
        local options = {}
        for key, value in pairs(definition.skinOptions or {}) do
            options[key] = value
        end
        options.style = style
        if options.border == nil then options.border = borderColor end
        for _, key in ipairs({
            "collapsible", "expanded", "text", "textRegion", "icon",
            "getExpanded", "isExpanded", "height", "stripArtwork",
            "artworkRegions", "preserveTextures", "background",
            "visualRegion", "preserveTextLayout", "hoverRegion", "getHovered",
        }) do
            if options[key] == nil then options[key] = definition[key] end
        end
        skinMethod(self, target, options)
    end,
    ACTION_BUTTON = function(self, skinMethod, target, style, borderColor,
        definition)
        local options = {}
        for key, value in pairs(definition.skinOptions or {}) do
            options[key] = value
        end
        options.style = style
        if options.border == nil then options.border = borderColor end
        skinMethod(self, target, options)
    end,
    CHECKBOX = function(self, skinMethod, target, style, borderColor, definition)
        local options = {}
        for key, value in pairs(definition.skinOptions or {}) do
            options[key] = value
        end
        options.style = style
        if options.border == nil then options.border = borderColor end
        if options.text == nil then options.text = definition.text end
        if options.getChecked == nil then
            options.getChecked = definition.getChecked
        end
        skinMethod(self, target, options)
    end,
    DROPDOWN = function(self, skinMethod, target, style, borderColor, definition)
        local options = {}
        for key, value in pairs(definition.skinOptions or {}) do
            options[key] = value
        end
        options.style = style
        if options.border == nil then options.border = borderColor end
        options.menus = definition.menus
        skinMethod(self, target, options)
    end,
    SEARCH_ACCESSORY = function(self, skinMethod, target, style, borderColor,
        definition)
        local options = {}
        for key, value in pairs(definition.skinOptions or {}) do
            options[key] = value
        end
        options.style = style
        if options.border == nil then options.border = borderColor end
        options.menus = definition.menus
        skinMethod(self, target, options)
    end,
    SCROLLBAR = function(self, skinMethod, target, style)
        skinMethod(self, target, style)
    end,
    SEARCH_GROUP = function(self, skinMethod, target, style, borderColor)
        skinMethod(self, target, style, borderColor)
    end,
    EDIT_BOX = function(self, skinMethod, target, style, borderColor, definition)
        local options = {}
        for key, value in pairs(definition.skinOptions or {}) do
            options[key] = value
        end
        options.style = style
        if options.border == nil then options.border = borderColor end
        for _, key in ipairs({ "decrementButton", "incrementButton" }) do
            if options[key] == nil then options[key] = definition[key] end
        end
        options.spinnerButtonStyle = self:GetAppearanceStyle(
            "button", definition.appearanceWindowID, definition.id)
        options.spinnerButtonBorder = self:GetAppearanceBorderColor(
            "button", options.spinnerButtonStyle,
            definition.appearanceWindowID, definition.id)
        skinMethod(self, target, options)
    end,
    ICON = function(self, skinMethod, target, style, borderColor, definition)
        local options = {}
        for key, value in pairs(definition.skinOptions or {}) do
            options[key] = value
        end
        options.style = style
        for _, key in ipairs({
            "texture", "quality", "qualityProvider", "borderColor", "borderMode",
            "borderSize", "borderPadding", "borderKey", "borderOwner",
            "outside", "showBorder", "width", "height", "zoom", "crop",
            "shape", "nativeDecorationRegions", "nativeBorderRegions",
            "hoverRegion", "hoverRegions", "selectedRegion",
            "getHovered", "getSelected",
            "interactionAlpha",
        }) do
            if options[key] == nil then options[key] = definition[key] end
        end
        options.baselineID = definition.iconTextureBaselineID
        options.borderColor = options.borderColor or borderColor
        skinMethod(self, definition.iconTarget or target, options)
    end,
    TEXT = function(self, skinMethod, target, style, _, definition)
        skinMethod(self, target, style, {
            numberFormat = definition.numberFormat,
            suffixIcon = definition.suffixIcon,
        })
    end,
}

function NSkin:SkinTypedElement(typeID, definition)
    if type(definition) ~= "table" or not definition.target then return false end
    local typeDefinition = self:GetSharedElementType(typeID)
    local adapter = SHARED_SKIN_ADAPTERS[typeID]
    local skinMethod = typeDefinition and self[typeDefinition.skin]
    if not typeDefinition or not adapter or type(skinMethod) ~= "function" then
        return false
    end
    local style = self:GetAppearanceStyle(typeDefinition.style,
        definition.appearanceWindowID, definition.id)
    local borderColor = self:GetAppearanceBorderColor(
        typeDefinition.style, style, definition.appearanceWindowID, definition.id)
    if type(definition.skinAdapter) == "function" then
        definition.skinAdapter(self, definition.target, style, borderColor,
            definition)
    else
        adapter(self, skinMethod, definition.target, style, borderColor,
            definition)
    end
    return true
end

function NSkin:ResnapPixelBordersForElement(elementOrID)
    local element = type(elementOrID) == "table" and elementOrID
        or skinningElements[elementOrID]
    if not element then return false end
    local requested = self:ResnapPixelBordersForTarget(element.target)
    local targets = element.pixelBorderTargets
    if type(targets) == "function" then targets = targets(element) end
    for i = 1, #(targets or {}) do
        requested = self:ResnapPixelBordersForTarget(targets[i]) or requested
    end
    return requested
end

function NSkin:RefreshTypedElementAppearance(element)
    if not element or not element.typedRegistration then return false end
    if not self:SkinTypedElement(element.kind, element) then return false end
    return true
end

function NSkin:RefreshTypedElementLayout(element)
    if not self:RefreshTypedElementAppearance(element) then return false end
    local saved = self:GetSavedMovableElementPlacement(element.id)
    if saved and element.applyPlacement and self:IsSkinningElementEditable(element) then
        element.applyPlacement(element, saved, SUPPRESS_NOTIFICATION)
    end
    self:NotifySkinningElementBoundsChanged(element.id)
    self:ResnapPixelBordersForElement(element)
    return true
end

function NSkin:RefreshTypedElement(element, requirement)
    if requirement == "layout" then
        return self:RefreshTypedElementLayout(element)
    end
    return self:RefreshTypedElementAppearance(element)
end

local COMMON_TYPED_SKIN_FIELDS = { "skinAdapter", "skinOptions" }
local TYPED_SKIN_FIELDS_BY_TYPE = {
    COLUMN_HEADER = {
        "textRegion", "artworkRegions", "preserveTextures", "hoverRegion",
        "getHovered", "visualRegion",
    },
    ROW = {
        "nativeDecorationRegions", "artworkRegions", "preserveTextures", "hoverRegion",
        "selectedRegion", "getHovered", "getSelected", "visualRegion",
        "contentRegions", "contentStyle", "height", "reset",
    },
    CHECKBOX = { "text", "getChecked" },
    DROPDOWN = { "menus" },
    SEARCH_ACCESSORY = { "menus" },
    SECTION_CARD = {
        "collapsible", "expanded", "text", "textRegion", "icon",
        "getExpanded", "isExpanded", "height", "stripArtwork",
        "artworkRegions", "preserveTextures", "background", "visualRegion",
        "preserveTextLayout", "hoverRegion", "getHovered",
    },
    EDIT_BOX = { "decrementButton", "incrementButton" },
    ICON = {
        "iconTarget", "iconTextureBaselineID",
        "texture", "quality", "qualityProvider", "borderColor", "borderMode",
        "borderSize", "borderPadding", "borderKey", "borderOwner", "outside",
        "showBorder", "width", "height", "zoom", "crop", "shape",
        "nativeDecorationRegions", "nativeBorderRegions",
        "hoverRegion", "hoverRegions", "selectedRegion",
        "getHovered", "getSelected",
        "interactionAlpha",
    },
    TEXT = { "numberFormat", "suffixIcon" },
}

local function TypedSkinValuesEqual(left, right, visited)
    if left == right then return true end
    if type(left) ~= "table" or type(right) ~= "table" then return false end
    visited = visited or {}
    if visited[left] == right then return true end
    visited[left] = right
    for key, value in pairs(left) do
        local other = right[key]
        if value ~= other then
            if type(value) ~= "table" or type(other) ~= "table"
                or not TypedSkinValuesEqual(value, other, visited)
            then
                return false
            end
        end
    end
    for key in pairs(right) do
        if left[key] == nil then return false end
    end
    return true
end

local function TypedSkinDefinitionChanged(typeID, existing, definition)
    for i = 1, #COMMON_TYPED_SKIN_FIELDS do
        local key = COMMON_TYPED_SKIN_FIELDS[i]
        if not TypedSkinValuesEqual(existing[key], definition[key]) then return true end
    end
    local fields = TYPED_SKIN_FIELDS_BY_TYPE[typeID]
    for i = 1, #(fields or {}) do
        local key = fields[i]
        if not TypedSkinValuesEqual(existing[key], definition[key]) then return true end
    end
    return false
end

function NSkin:RegisterTypedElement(typeID, definition)
    if type(definition) ~= "table" or type(definition.id) ~= "string"
        or not definition.target
    then return nil end
    local existing = self:GetSkinningElement(definition.id)
    if existing and existing.typedRegistration and existing.kind == typeID
        and existing.target == definition.target
        and existing.window == definition.window
    then
        if definition == existing then
            return existing
        end
        local skinChanged = TypedSkinDefinitionChanged(typeID, existing, definition)
        if definition.applyPlacement then existing.applyPlacement = definition.applyPlacement end
        if definition.editorOptions then existing.editorOptions = definition.editorOptions end
        -- Keep the canonical object and its generated placement/reset callbacks.
        -- Remember supplied fields so removed optional skin settings do not linger.
        for key in pairs(existing.typedDefinitionKeys) do
            if definition[key] == nil then existing[key] = nil end
            existing.typedDefinitionKeys[key] = nil
        end
        for key, value in pairs(definition) do
            if key ~= "editorOptions" and key ~= "extraEditorOptions"
                and key ~= "kind" and key ~= "applyPlacement"
            then
                existing[key] = value
                existing.typedDefinitionKeys[key] = true
            end
        end
        if skinChanged then self:RefreshTypedElementAppearance(existing) end
        return existing
    end
    local typeDefinition = self:GetSharedElementType(typeID)
    if not typeDefinition or not self:SkinTypedElement(typeID, definition) then
        return nil
    end

    if existing then
        -- A different target/type cannot reuse the original geometry ownership.
        -- Retain the legacy registration path and broad appearance fallback.
        existing.requiresStructuralRefresh = true
        return self:RegisterSimpleMovableElement(definition)
    end

    local element = {}
    for key, value in pairs(definition) do element[key] = value end
    element.typedRegistration = true
    element.typedDefinitionKeys = {}
    for key in pairs(definition) do
        if key ~= "editorOptions" and key ~= "extraEditorOptions"
            and key ~= "kind" and key ~= "applyPlacement"
        then element.typedDefinitionKeys[key] = true end
    end
    element.kind = typeID
    if not element.editorOptions then
        element.editorOptions = self:CreateEditorOptionsPreset(
            typeDefinition.editorPreset or typeID,
            element.extraEditorOptions)
    end
    if element.preserveAnchorSpan == nil then
        element.preserveAnchorSpan = typeDefinition.preserveAnchorSpan
    end
    return self:RegisterSimpleMovableElement(element)
end

function NSkin:RegisterActionButton(definition)
    return self:RegisterTypedElement("ACTION_BUTTON", definition)
end

function NSkin:RegisterSectionCard(definition)
    return self:RegisterTypedElement("SECTION_CARD", definition)
end

function NSkin:RegisterCheckbox(definition)
    return self:RegisterTypedElement("CHECKBOX", definition)
end

function NSkin:RegisterDropdown(definition)
    return self:RegisterTypedElement("DROPDOWN", definition)
end

function NSkin:RegisterScrollBar(definition)
    return self:RegisterTypedElement("SCROLLBAR", definition)
end

function NSkin:RegisterSearchBox(definition)
    return self:RegisterTypedElement("SEARCH_GROUP", definition)
end

function NSkin:RegisterEditBox(definition)
    return self:RegisterTypedElement("EDIT_BOX", definition)
end

function NSkin:RegisterIcon(definition)
    if type(definition) ~= "table" or type(definition.id) ~= "string"
        or definition.id == "" or not definition.target
    then return nil end

    -- The caller's target is the logical control that supplies icon state and
    -- quality. The texture is the presentation geometry Skinning Mode edits.
    -- Keeping those roles separate prevents an icon size/position override
    -- from resizing or moving its containing Button/Frame.
    local iconTarget = definition.iconTarget or definition.target
    local skinOptions = definition.skinOptions
    local texture = definition.texture
        or (skinOptions and skinOptions.texture)
    if not texture then
        if iconTarget.GetObjectType
            and iconTarget:GetObjectType() == "Texture"
        then
            texture = iconTarget
        else
            texture = iconTarget.Icon or iconTarget.icon
                or iconTarget.iconTexture
        end
    end
    if not texture then return nil end

    local normalized = {}
    for key, value in pairs(definition) do normalized[key] = value end
    normalized.iconTarget = iconTarget
    normalized.target = texture
    normalized.texture = texture
    normalized.iconTextureBaselineID = definition.iconTextureBaselineID
        or (definition.id .. ":texture")

    local borderOwner = definition.borderOwner
        or (skinOptions and skinOptions.borderOwner)
    if not borderOwner then
        if iconTarget.GetObjectType
            and iconTarget:GetObjectType() ~= "Texture"
        then
            borderOwner = iconTarget
        elseif texture.GetParent then
            borderOwner = texture:GetParent()
        end
    end
    normalized.borderOwner = borderOwner
    if definition.highlightRegions == nil then
        normalized.highlightRegions = { texture }
    end
    if definition.pixelBorderTargets == nil and borderOwner then
        normalized.pixelBorderTargets = { borderOwner }
    end
    local element = self:RegisterTypedElement("ICON", normalized)
    if element then
        local state = self:GetSkinData(iconTarget, "iconComponent", false)
        if state and state.active ~= true then
            self:RefreshTypedElementAppearance(element)
        end
    end
    return element
end

function NSkin:RegisterColumnHeader(definition)
    return self:RegisterTypedElement("COLUMN_HEADER", definition)
end

function NSkin:RegisterRow(definition)
    return self:RegisterTypedElement("ROW", definition)
end

function NSkin:RegisterTextElement(definition)
    return self:RegisterTypedElement("TEXT", definition)
end

local function GetControllerState(module, id, create)
    local options = NSkin:GetModuleOptions(module, create == true)
    if not options then return end
    if create and not options.componentStates then options.componentStates = {} end
    local states = options.componentStates
    if not states then return nil, options end
    if create and not states[id] then states[id] = {} end
    return states[id], options
end

local function PruneControllerState(module, options, id)
    local states = options and options.componentStates
    local state = states and states[id]
    if state and not next(state) then states[id] = nil end
    if states and not next(states) then options.componentStates = nil end
    if options and not next(options) then
        local profile = NSkin:GetProfile()
        if profile.moduleOptions then
            profile.moduleOptions[module] = nil
            if not next(profile.moduleOptions) then profile.moduleOptions = nil end
        end
    end
end

local function RegisterControllerElement(controller, id, label, target, options)
    if not id or not target then return end
    options = options or {}
    local elementDefinition = {
        id = id,
        module = controller.module,
        appearanceWindowID = controller.appearanceWindowID,
        label = label,
        kind = options.kind,
        window = controller.window,
        target = target,
        editorOptions = options.editorOptions,
        defaultPlacement = CopyPlacement(options.defaultPlacement
            or GetCurrentWindowPlacement(controller.window, target)),
        priority = options.priority,
        anchorHighlight = options.anchorHighlight,
        highlightRegions = options.highlightRegions,
        isEditable = options.isEditable,
        applyPlacement = options.applyPlacement,
        snapTarget = options.snapTarget,
        livePreview = options.livePreview,
        draggable = options.draggable,
        skinOptions = options.skinOptions,
        menus = options.menus,
        refreshAppearance = options.refreshAppearance,
        refreshLayout = options.refreshLayout,
        pixelBorderTargets = options.pixelBorderTargets,
        requiresStructuralRefresh = options.requiresStructuralRefresh == true,
    }
    if SHARED_SKIN_ADAPTERS[options.kind] then
        NSkin:RegisterTypedElement(options.kind, elementDefinition)
    else
        NSkin:RegisterMovableElement(elementDefinition)
    end
    return skinningElements[id]
end

function NSkin:WouldCreateSkinningPlacementCycle(elementID, relativeTo)
    local visited = {}
    local current = relativeTo
    while current do
        if current == elementID or visited[current] then return true end
        visited[current] = true
        local element = skinningElements[current]
        if not element or type(element.getPlacement) ~= "function" then return false end
        local placement = element.getPlacement(element)
        current = placement and placement.relativeTo
    end
    return false
end

function NSkin:GetUIParentNormalizedBounds(region, left, right, bottom, top)
    if not region or not region.GetEffectiveScale or not UIParent
        or not UIParent.GetEffectiveScale
    then
        return
    end
    left = left or (region.GetLeft and region:GetLeft())
    right = right or (region.GetRight and region:GetRight())
    bottom = bottom or (region.GetBottom and region:GetBottom())
    top = top or (region.GetTop and region:GetTop())
    if not left or not right or not bottom or not top then return end
    local parentScale = UIParent:GetEffectiveScale()
    local regionScale = region:GetEffectiveScale()
    if not parentScale or parentScale == 0 or not regionScale then return end
    local scale = regionScale / parentScale
    return left * scale, right * scale, bottom * scale, top * scale
end

function NSkin:GetSkinningElementBounds(element)
    if not element then return end
    local regions = element.highlightRegions
    if type(regions) == "function" then regions = regions(element) end
    if type(regions) == "table" then
        local left, right, bottom, top
        for i = 1, #regions do
            local region = regions[i]
            if region and (not region.IsShown or region:IsShown()) then
                local regionLeft, regionRight, regionBottom, regionTop =
                    self:GetUIParentNormalizedBounds(region)
                if regionLeft then
                    left = not left and regionLeft or math.min(left, regionLeft)
                    right = not right and regionRight or math.max(right, regionRight)
                    bottom = not bottom and regionBottom or math.min(bottom, regionBottom)
                    top = not top and regionTop or math.max(top, regionTop)
                end
            end
        end
        if left then return left, right, bottom, top end
    end
    if type(element.getHighlightBounds) == "function" then
        local ok, left, right, bottom, top = pcall(element.getHighlightBounds, element)
        if ok and left and right and bottom and top then
            return self:GetUIParentNormalizedBounds(
                element.target or element.window, left, right, bottom, top
            )
        end
    end

    if element.kind == "TAB_GROUP" then
        local tabs = element.container and element.container.tabs or element.tabs
        local left, right, bottom, top
        if type(tabs) == "table" then
            for i = 1, #tabs do
                local tab = tabs[i]
                if tab and (not tab.IsShown or tab:IsShown()) then
                    local tabLeft, tabRight = tab:GetLeft(), tab:GetRight()
                    local tabBottom, tabTop = tab:GetBottom(), tab:GetTop()
                    if tabLeft and tabRight and tabBottom and tabTop then
                        tabLeft, tabRight, tabBottom, tabTop =
                            self:GetUIParentNormalizedBounds(
                                tab, tabLeft, tabRight, tabBottom, tabTop
                            )
                        left = not left and tabLeft or math.min(left, tabLeft)
                        right = not right and tabRight or math.max(right, tabRight)
                        bottom = not bottom and tabBottom or math.min(bottom, tabBottom)
                        top = not top and tabTop or math.max(top, tabTop)
                    end
                end
            end
        end
        if left then return left, right, bottom, top end
    end

    local target = element.target
    if not target or (target.IsShown and not target:IsShown()) then return end
    if not target.GetLeft then return end
    return self:GetUIParentNormalizedBounds(target)
end

function NSkin:NotifySkinningElementBoundsChanged(elementID)
    local element = skinningElements[elementID]
    if not element then return false end
    FireComponentCallback("SkinningElementBoundsChanged", element)
    return true
end

COMPONENT_INTERNALS.tabGroups = tabGroups
COMPONENT_INTERNALS.tabGroupOriginalPoints = tabGroupOriginalPoints
COMPONENT_INTERNALS.skinningElements = skinningElements
COMPONENT_INTERNALS.windowSequence = windowSequence
COMPONENT_INTERNALS.CopyPlacement = CopyPlacement
COMPONENT_INTERNALS.FireComponentCallback = FireComponentCallback
COMPONENT_INTERNALS.CaptureFramePoints = CaptureFramePoints
COMPONENT_INTERNALS.RestoreFramePoints = RestoreFramePoints
COMPONENT_INTERNALS.GetCurrentWindowPlacement = GetCurrentWindowPlacement
COMPONENT_INTERNALS.GetSavedMovablePlacement = GetSavedMovablePlacement
COMPONENT_INTERNALS.ClearSavedMovablePlacement = ClearSavedMovablePlacement
COMPONENT_INTERNALS.GetControllerState = GetControllerState
COMPONENT_INTERNALS.PruneControllerState = PruneControllerState
COMPONENT_INTERNALS.RegisterControllerElement = RegisterControllerElement
