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
        if type(defaultValue) == "table" and type(override) == "table" then
            result[key] = CopyWithOverrides(defaultValue, override)
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
