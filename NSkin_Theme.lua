local _, NSkin = ...

local resolvedStyles = {}

local function TablesEqual(left, right)
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
    return result
end

function NSkin:GetStyle(name)
    local cached = resolvedStyles[name]
    if cached then return cached end

    local defaults = self.defaultTheme and self.defaultTheme[name]
    if type(defaults) ~= "table" then return nil end

    local profile = self:GetProfile()
    local overrides = profile.theme and profile.theme[name]
    cached = CopyWithOverrides(defaults, overrides)
    resolvedStyles[name] = cached
    return cached
end

function NSkin:GetBorderAccentColor()
    return self:GetStyle("window").border
end

function NSkin:SetBorderAccentColor(color)
    if type(color) ~= "table" then return false end
    return self:SetThemeOverride("window.border", color)
end

function NSkin:ResetBorderAccentColor()
    return self:ResetThemeOverride("window.border")
end

function NSkin:GetTabSpacing()
    return self:GetStyle("tab").spacing
end

local function RefreshTabLayouts()
    NSkin:InvalidateTheme()
    if NSkin.RefreshRegisteredTabGroups then NSkin:RefreshRegisteredTabGroups() end
end

local function SetTabLayoutOverride(path, value)
    local defaultValue = GetPath(NSkin.defaultTheme, path, false)
    local profile = NSkin:GetProfile()
    profile.theme = profile.theme or {}
    local _, parent, key = GetPath(profile.theme, path, true)
    parent[key] = value == defaultValue and nil or value
    PruneEmptyTables(profile.theme)
    if not next(profile.theme) then profile.theme = nil end
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
    return SetTabLayoutOverride("tab.spacing", self.defaultTheme.tab.spacing)
end

function NSkin:GetBottomTabAnchor()
    return self:GetStyle("tab").bottom.anchor
end

function NSkin:GetBottomTabOffsetX()
    return self:GetStyle("tab").bottom.offsetX
end

function NSkin:GetBottomTabOffsetY()
    return self:GetStyle("tab").bottom.offsetY
end

function NSkin:GetBottomTabPlacement()
    local layout = self:GetStyle("tab").bottom
    return {
        alignment = layout.anchor,
        alongOffset = layout.offsetX,
        edgeOffset = layout.offsetY,
    }
end

function NSkin:SetBottomTabPlacement(placement)
    if type(placement) ~= "table" then return false end
    local alignment = placement.alignment
    if alignment ~= "LEFT" and alignment ~= "CENTER" and alignment ~= "RIGHT" then
        return false
    end
    local alongOffset = tonumber(placement.alongOffset)
    local edgeOffset = tonumber(placement.edgeOffset)
    if not alongOffset or not edgeOffset then return false end
    alongOffset = math.max(-100, math.min(100, math.floor(alongOffset + 0.5)))
    edgeOffset = math.max(-100, math.min(100, math.floor(edgeOffset + 0.5)))

    local profile = self:GetProfile()
    profile.theme = profile.theme or {}
    profile.theme.tab = profile.theme.tab or {}
    profile.theme.tab.bottom = profile.theme.tab.bottom or {}
    local bottom = profile.theme.tab.bottom
    local defaults = self.defaultTheme.tab.bottom
    bottom.anchor = alignment == defaults.anchor and nil or alignment
    bottom.offsetX = alongOffset == defaults.offsetX and nil or alongOffset
    bottom.offsetY = edgeOffset == defaults.offsetY and nil or edgeOffset
    PruneEmptyTables(profile.theme)
    if not next(profile.theme) then profile.theme = nil end
    RefreshTabLayouts()
    return true
end

function NSkin:SetBottomTabAnchor(anchor)
    if anchor ~= "LEFT" and anchor ~= "CENTER" and anchor ~= "RIGHT" then
        return false
    end
    local placement = self:GetBottomTabPlacement()
    placement.alignment = anchor
    return self:SetBottomTabPlacement(placement)
end

function NSkin:SetBottomTabOffsetX(offset)
    offset = tonumber(offset)
    if not offset then return false end
    local placement = self:GetBottomTabPlacement()
    placement.alongOffset = offset
    return self:SetBottomTabPlacement(placement)
end

function NSkin:SetBottomTabOffsetY(offset)
    offset = tonumber(offset)
    if not offset then return false end
    local placement = self:GetBottomTabPlacement()
    placement.edgeOffset = offset
    return self:SetBottomTabPlacement(placement)
end

function NSkin:ResetBottomTabLayout()
    local defaults = self.defaultTheme.tab.bottom
    return self:SetBottomTabPlacement({
        alignment = defaults.anchor,
        alongOffset = defaults.offsetX,
        edgeOffset = defaults.offsetY,
    })
end

function NSkin:InvalidateTheme()
    wipe(resolvedStyles)
end

function NSkin:RefreshTheme()
    self:InvalidateTheme()

    if self.RefreshOptionsTheme then self:RefreshOptionsTheme() end
    for _, module in pairs(self.modules) do
        if self:IsModuleEnabled(module.name) and type(module.RefreshTheme) == "function" then
            module:RefreshTheme()
        end
    end
    if self.RefreshRegisteredTabGroups then self:RefreshRegisteredTabGroups() end
end

function NSkin:SetThemeOverride(path, value)
    if type(path) ~= "string" or path == "" then return false end
    local defaultValue = GetPath(self.defaultTheme, path, false)
    if defaultValue == nil or type(defaultValue) ~= type(value) then return false end

    local profile = self:GetProfile()
    profile.theme = profile.theme or {}
    local _, parent, key = GetPath(profile.theme, path, true)
    parent[key] = TablesEqual(value, defaultValue) and nil or value
    PruneEmptyTables(profile.theme)
    if not next(profile.theme) then profile.theme = nil end
    self:RefreshTheme()
    return true
end

function NSkin:ResetThemeOverride(path)
    if type(path) ~= "string" or path == "" then return false end
    local profile = self:GetProfile()
    if not profile.theme then return true end

    local _, parent, key = GetPath(profile.theme, path, false)
    if parent then parent[key] = nil end
    PruneEmptyTables(profile.theme)
    if not next(profile.theme) then profile.theme = nil end
    self:RefreshTheme()
    return true
end
