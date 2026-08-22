local _, NSkin = ...

local DEFAULT_PROFILE = "Default"
local activeProfile

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
    end
    if database.statusBarTexture ~= nil and profile.statusBarTexture == nil then
        profile.statusBarTexture = database.statusBarTexture
    end
    if database.spellBookTextSize ~= nil then
        profile.moduleOptions = profile.moduleOptions or {}
        profile.moduleOptions.SpellBook = profile.moduleOptions.SpellBook or {}
        if profile.moduleOptions.SpellBook.textSize == nil then
            profile.moduleOptions.SpellBook.textSize = database.spellBookTextSize
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
