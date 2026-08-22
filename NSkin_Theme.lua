local _, NSkin = ...

local resolvedStyles = {}

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
