local _, NSkin = ...

local resolvedStyles = {}

local function RoundOne(value)
    value = tonumber(value) or 0
    if value >= 0 then return math.floor(value * 10 + 0.5) / 10 end
    return math.ceil(value * 10 - 0.5) / 10
end

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

function NSkin:GetTabPlacement()
    local layout = self:GetStyle("tab").bottom
    return {
        mode = layout.mode,
        point = layout.point,
        relativePoint = layout.relativePoint,
        x = layout.x,
        y = layout.y,
        edge = layout.edge or "BOTTOM",
        side = layout.side or "OUTSIDE",
        alignment = layout.anchor,
        alongOffset = layout.offsetX,
        edgeOffset = layout.offsetY,
    }
end

function NSkin:SetTabPlacement(placement)
    if type(placement) ~= "table" then return false end
    local profile = self:GetProfile()
    profile.theme = profile.theme or {}
    profile.theme.tab = profile.theme.tab or {}
    profile.theme.tab.bottom = profile.theme.tab.bottom or {}
    local bottom = profile.theme.tab.bottom
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

    local defaults = self.defaultTheme.tab.bottom
    bottom.mode, bottom.point, bottom.relativePoint, bottom.x, bottom.y = nil, nil, nil, nil, nil
    bottom.edge = edge == defaults.edge and nil or edge
    bottom.side = side == defaults.side and nil or side
    bottom.anchor = alignment == defaults.anchor and nil or alignment
    bottom.offsetX = alongOffset == defaults.offsetX and nil or alongOffset
    bottom.offsetY = edgeOffset == defaults.offsetY and nil or edgeOffset
    PruneEmptyTables(profile.theme)
    if not next(profile.theme) then profile.theme = nil end
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
    local defaults = self.defaultTheme.tab.bottom
    return self:SetTabPlacement({
        edge = defaults.edge,
        side = defaults.side,
        alignment = defaults.anchor,
        alongOffset = defaults.offsetX,
        edgeOffset = defaults.offsetY,
    })
end


function NSkin:ResetBottomTabLayout()
    return self:ResetTabLayout()
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
