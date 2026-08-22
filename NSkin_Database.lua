local _, NSkin = ...

local DEFAULT_PROFILE = "Default"
local activeProfile

local function CopyTable(source)
    local result = {}
    for key, value in pairs(source) do
        result[key] = type(value) == "table" and CopyTable(value) or value
    end
    return result
end

local function NormalizeProfileName(name)
    if type(name) ~= "string" then return nil end
    name = name:match("^%s*(.-)%s*$")
    if name == "" then return nil end
    return name
end

local function GetCharacterKey()
    local name = _G.UnitName and _G.UnitName("player")
    local realm = _G.GetRealmName and _G.GetRealmName()
    if not name or name == "" or not realm or realm == "" then
        return nil
    end
    return name .. "-" .. realm
end

local function MigrateLegacyDatabase(database, profile)
    if database.modules and profile.modules == nil then
        profile.modules = database.modules
        for moduleName, enabled in pairs(profile.modules) do
            if (enabled == true) == (NSkin.defaultModules[moduleName] == true) then
                profile.modules[moduleName] = nil
            end
        end
        if not next(profile.modules) then profile.modules = nil end
    end
    if database.statusBarTexture ~= nil and profile.statusBarTexture == nil then
        local defaultTexture = NSkin.defaultTheme.progressBar.texture
        if database.statusBarTexture ~= defaultTexture then
            profile.statusBarTexture = database.statusBarTexture
        end
    end
    if database.spellBookTextSize ~= nil then
        local defaultSize = NSkin.defaultModuleOptions.SpellBook.textSize
        if database.spellBookTextSize ~= defaultSize then
            profile.moduleOptions = profile.moduleOptions or {}
            profile.moduleOptions.SpellBook = profile.moduleOptions.SpellBook or {}
            if profile.moduleOptions.SpellBook.textSize == nil then
                profile.moduleOptions.SpellBook.textSize = database.spellBookTextSize
            end
        end
    end

    database.modules = nil
    database.statusBarTexture = nil
    database.spellBookTextSize = nil
end

function NSkin:GetDatabase()
    _G.NSkinDB = _G.NSkinDB or {}
    local database = _G.NSkinDB
    database.profileKeys = database.profileKeys or {}
    database.profiles = database.profiles or {}
    database.profiles[DEFAULT_PROFILE] = database.profiles[DEFAULT_PROFILE] or {}
    return database
end

function NSkin:GetProfileName()
    if activeProfile then return activeProfile end

    local database = self:GetDatabase()
    local characterKey = GetCharacterKey()
    local profileName = characterKey and database.profileKeys[characterKey] or nil
    if type(profileName) ~= "string" or profileName == "" then
        profileName = DEFAULT_PROFILE
        if characterKey then database.profileKeys[characterKey] = profileName end
    end

    database.profiles[profileName] = database.profiles[profileName] or {}
    MigrateLegacyDatabase(database, database.profiles[profileName])
    activeProfile = profileName
    return profileName
end

function NSkin:GetProfile()
    local database = self:GetDatabase()
    return database.profiles[self:GetProfileName()]
end

function NSkin:GetModuleOptions(moduleName, create)
    local profile = self:GetProfile()
    local options = profile.moduleOptions
    if not options then
        if not create then return nil end
        options = {}
        profile.moduleOptions = options
    end

    local moduleOptions = options[moduleName]
    if not moduleOptions and create then
        moduleOptions = {}
        options[moduleName] = moduleOptions
    end
    return moduleOptions
end

function NSkin:CreateProfile(name)
    name = NormalizeProfileName(name)
    if not name then return false, "A profile name is required." end

    local profiles = self:GetDatabase().profiles
    if profiles[name] then return false, "That profile already exists." end
    profiles[name] = {}
    return true
end

function NSkin:CopyProfile(sourceName, destinationName)
    sourceName = NormalizeProfileName(sourceName)
    destinationName = NormalizeProfileName(destinationName)
    local profiles = self:GetDatabase().profiles
    if not sourceName or not profiles[sourceName] then
        return false, "The source profile does not exist."
    end
    if not destinationName then return false, "A destination profile name is required." end
    if profiles[destinationName] then return false, "That profile already exists." end

    profiles[destinationName] = CopyTable(profiles[sourceName])
    return true
end

function NSkin:SelectProfile(name)
    name = NormalizeProfileName(name)
    local database = self:GetDatabase()
    if not name or not database.profiles[name] then
        return false, "That profile does not exist."
    end

    local characterKey = GetCharacterKey()
    if characterKey then database.profileKeys[characterKey] = name end
    activeProfile = name
    if self.RefreshTheme then self:RefreshTheme() end
    return true
end

function NSkin:RenameProfile(oldName, newName)
    oldName = NormalizeProfileName(oldName)
    newName = NormalizeProfileName(newName)
    local database = self:GetDatabase()
    if not oldName or not database.profiles[oldName] then
        return false, "That profile does not exist."
    end
    if oldName == DEFAULT_PROFILE then return false, "The Default profile cannot be renamed." end
    if not newName then return false, "A new profile name is required." end
    if database.profiles[newName] then return false, "That profile already exists." end

    database.profiles[newName] = database.profiles[oldName]
    database.profiles[oldName] = nil
    for characterKey, profileName in pairs(database.profileKeys) do
        if profileName == oldName then database.profileKeys[characterKey] = newName end
    end
    if activeProfile == oldName then activeProfile = newName end
    return true
end

function NSkin:DeleteProfile(name)
    name = NormalizeProfileName(name)
    local database = self:GetDatabase()
    if not name or not database.profiles[name] then
        return false, "That profile does not exist."
    end
    if name == DEFAULT_PROFILE then return false, "The Default profile cannot be deleted." end

    database.profiles[name] = nil
    for characterKey, profileName in pairs(database.profileKeys) do
        if profileName == name then database.profileKeys[characterKey] = DEFAULT_PROFILE end
    end
    if activeProfile == name then
        activeProfile = DEFAULT_PROFILE
        if self.RefreshTheme then self:RefreshTheme() end
    end
    return true
end

function NSkin:ResetProfile(name)
    name = NormalizeProfileName(name) or self:GetProfileName()
    local profiles = self:GetDatabase().profiles
    if not profiles[name] then return false, "That profile does not exist." end
    profiles[name] = {}
    if activeProfile == name and self.RefreshTheme then self:RefreshTheme() end
    return true
end
