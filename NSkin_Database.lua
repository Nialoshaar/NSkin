do
local _, NSkin = ...

-- Immutable visual styling only. Geometry belongs to explicit profile
-- overrides; an absent value always means preserve Blizzard's live state.
NSkin.baseAppearance = {
    typography = {
        font = "Fonts\\FRIZQT__.TTF",
        outline = "",
    },

    text = {
        color = { 1, 1, 1, 1 },
        colorMode = "CUSTOM",
        font = "Fonts\\FRIZQT__.TTF",
        outline = "",
        useGlobalTypography = true,
        fontMode = "GLOBAL",
        sizeMode = "BLIZZARD",
        outlineMode = "GLOBAL",
    },

    accent = {
        enabled = false,
        color = { 0, 0.55, 0.82, 1 },
    },

    window = {
        background = { 0, 0, 0, 0.80 },
        backgroundMode = "CUSTOM",
        border = { 0.45, 0.45, 0.45, 1 },
        borderMode = "CUSTOM",
        borderSize = 1,
        borderPadding = 0,

        header = {
            background = { 0.04, 0.04, 0.04, 0.95 },
            backgroundMode = "CUSTOM",
            divider = { 0.45, 0.45, 0.45, 1 },
            matchBackground = false,
            text = { 1, 1, 1, 1 },
            textMode = "CUSTOM",
            font = "Fonts\\FRIZQT__.TTF",
            outline = "",
            useGlobalTypography = true,
            fontMode = "GLOBAL",
            sizeMode = "GLOBAL",
            outlineMode = "GLOBAL",
        },
    },

    tab = {
        background = { 0.04, 0.04, 0.04, 0.90 },
        backgroundMode = "CUSTOM",
        selectedBackground = { 0.16, 0.16, 0.16, 0.95 },
        selectedBackgroundMode = "CUSTOM",
        border = { 0.45, 0.45, 0.45, 1 },
        borderMode = "CUSTOM",
        text = { 1, 1, 1, 1 },
        textMode = "CUSTOM",
        hoverAlpha = 0.10,
        borderSize = 1,
        borderPadding = 0,
        font = "Fonts\\FRIZQT__.TTF",
        outline = "",
        useGlobalTypography = true,
        fontMode = "GLOBAL",
        sizeMode = "GLOBAL",
        outlineMode = "GLOBAL",
    },

    button = {
        background = { 0.04, 0.04, 0.04, 0.90 },
        border = { 0.45, 0.45, 0.45, 1 },
        text = { 1, 1, 1, 1 },
        hoverAlpha = 0.10,
    },

    windowHeaderButton = {
        background = { 0.04, 0.04, 0.04, 0.90 },
        backgroundMode = "CUSTOM",
        border = { 0.45, 0.45, 0.45, 1 },
        borderMode = "CUSTOM",
        text = { 1, 1, 1, 1 },
        textSize = 20,
        hoverAlpha = 0.10,
        disabledTextAlpha = 0.45,
    },

    scrollBar = {
        track = { 0.25, 0.25, 0.25, 1 },
        trackMode = "CUSTOM",
        thumb = { 0, 0.55, 0.82, 1 },
        thumbMode = "ACCENT",
        arrow = { 0, 0.55, 0.82, 1 },
        arrowMode = "ACCENT",
    },

    navigationBar = {
        background = { 0.04, 0.04, 0.04, 0.90 },
        homeBackground = { 0, 0, 0, 0.85 },
        homeBorder = { 0.45, 0.45, 0.45, 1 },
        homeText = { 1, 1, 1, 1 },
        disabledTextAlpha = 1,
        menuBackground = { 0.04, 0.04, 0.04, 0.95 },
        menuBorder = { 0.45, 0.45, 0.45, 1 },
        hoverAlpha = 0.10,
    },

    icon = {
        border = { 0, 0, 0, 1 },
        crop = 0.06,
        qualityColor = true,
    },

    searchBox = {
        background = { 0, 0, 0, 0.75 },
        backgroundMode = "CUSTOM",
        border = { 0.45, 0.45, 0.45, 1 },
        borderMode = "CUSTOM",
        text = { 1, 1, 1, 1 },
        textMode = "CUSTOM",
        placeholderText = { 0.55, 0.55, 0.55, 1 },
        placeholderTextMode = "CUSTOM",
        borderSize = 1,
        borderPadding = 0,
        font = "Fonts\\FRIZQT__.TTF",
        outline = "",
        useGlobalTypography = true,
        fontMode = "GLOBAL",
        sizeMode = "GLOBAL",
        outlineMode = "GLOBAL",
        placeholderFont = "Fonts\\FRIZQT__.TTF",
        placeholderOutline = "",
        placeholderUseGlobalTypography = true,
        placeholderFontMode = "GLOBAL",
        placeholderSizeMode = "GLOBAL",
        placeholderOutlineMode = "GLOBAL",
    },

    sectionHeader = {
        text = { 1, 1, 1, 1 },
        textMode = "CUSTOM",
        font = "Fonts\\FRIZQT__.TTF",
        outline = "",
        useGlobalTypography = true,
        fontMode = "GLOBAL",
        sizeMode = "GLOBAL",
        outlineMode = "GLOBAL",
        underlineVisible = true,
        underlineSize = 1,
        underline = { 0.45, 0.45, 0.45, 1 },
        underlineMode = "CUSTOM",
    },

    progressBar = {
        texture = "Interface\\Buttons\\WHITE8X8",
        background = { 0.06, 0.06, 0.06, 0.90 },
        border = { 0, 0, 0, 1 },
        useCustomColor = false,
        color = { 1, 1, 1, 1 },
        useCustomTextColor = false,
        text = { 1, 1, 1, 1 },
    },

    encounterCard = {
        background = { 0, 0, 0, 1 },
        border = { 0, 0, 0, 1 },
        hover = { 1, 1, 1, 0.14 },
    },

    skinningMode = {
        highlight = { 0, 0.65, 1, 0.16 },
        hover = { 0, 0.65, 1, 0.28 },
        dropZone = { 0, 0.65, 1, 0.22 },
        activeDropZone = { 0, 0.65, 1, 0.55 },
        gridAlpha = 0.4,
        ghost = { 0, 0.65, 1, 0.35 },
    },

    options = {
        accent = { 0, 0.55, 0.82, 1 },
        selectedNavigation = { 0, 0.55, 0.82, 0.85 },
        enabledNavigationText = { 1, 1, 1, 1 },
        disabledNavigationText = { 0.45, 0.45, 0.45, 1 },
        listBackground = { 0.07, 0.10, 0.11, 0.94 },
        selectedListBackground = { 0.12, 0.20, 0.23, 0.94 },
        listHighlight = { 0.38, 0.42, 0.43, 0.75 },
    },
}

end

local _, NSkin = ...

local DEFAULT_PROFILE = "Default"
local CURRENT_DATABASE_VERSION = 7
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

local function RemoveEmptyAppearanceTables(profile)
    local appearance = profile.appearance
    if not appearance then return end
    if appearance.progressBar and not next(appearance.progressBar) then
        appearance.progressBar = nil
    end
    if not next(appearance) then profile.appearance = nil end
end

local function MigrateVersion1(database, profile)
    if database.modules and profile.modules == nil then
        profile.modules = database.modules
        for moduleName, enabled in pairs(profile.modules) do
            if (enabled == true) == NSkin:GetModuleDefault(moduleName) then
                profile.modules[moduleName] = nil
            end
        end
        if not next(profile.modules) then profile.modules = nil end
    end

    if database.statusBarTexture ~= nil then
        local defaultTexture = NSkin.baseAppearance.progressBar.texture
        profile.appearance = profile.appearance or {}
        profile.appearance.progressBar = profile.appearance.progressBar or {}
        if database.statusBarTexture == defaultTexture then
            profile.appearance.progressBar.texture = nil
        else
            profile.appearance.progressBar.texture = database.statusBarTexture
        end
        RemoveEmptyAppearanceTables(profile)
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

local function MigrateVersion2(database)
    local defaultTexture = NSkin.baseAppearance.progressBar.texture
    for _, profile in pairs(database.profiles) do
        local texture = profile.statusBarTexture
        if texture ~= nil then
            profile.appearance = profile.appearance or {}
            profile.appearance.progressBar = profile.appearance.progressBar or {}
            if texture == defaultTexture then
                profile.appearance.progressBar.texture = nil
            else
                profile.appearance.progressBar.texture = texture
            end
            profile.statusBarTexture = nil
            RemoveEmptyAppearanceTables(profile)
        end
    end
end

local function MigrateVersion3(database)
    for _, profile in pairs(database.profiles) do
        local modules = profile.modules
        if modules and modules.ToyBox ~= nil then
            if modules.Collections == nil then
                modules.Collections = modules.ToyBox
            end
            modules.ToyBox = nil
            if not next(modules) then profile.modules = nil end
        end
    end
end

local function MigrateVersion4(database)
    for _, profile in pairs(database.profiles) do
        local moduleOptions = profile.moduleOptions
        local spellBook = moduleOptions and moduleOptions.SpellBook
        if spellBook then
            local mainTabs = spellBook.tabGroups and spellBook.tabGroups.MainTabs
            local placement = mainTabs and mainTabs.placement
            if placement then
                profile.appearance = profile.appearance or {}
                profile.appearance.tab = profile.appearance.tab or {}
                profile.appearance.tab.bottom = profile.appearance.tab.bottom or {}
                local bottom = profile.appearance.tab.bottom
                if bottom.anchor == nil then bottom.anchor = placement.alignment end
                if bottom.offsetX == nil then bottom.offsetX = placement.alongOffset end
                if bottom.offsetY == nil then bottom.offsetY = placement.edgeOffset end
                if not next(bottom) then profile.appearance.tab.bottom = nil end
                if not next(profile.appearance.tab) then profile.appearance.tab = nil end
                if not next(profile.appearance) then profile.appearance = nil end
            end
            spellBook.tabGroups = nil
            if not next(spellBook) then moduleOptions.SpellBook = nil end
            if not next(moduleOptions) then profile.moduleOptions = nil end
        end
    end
end

local function MergeSparse(target, source)
    for key, value in pairs(source or {}) do
        if type(value) == "table" then
            target[key] = type(target[key]) == "table" and target[key] or {}
            MergeSparse(target[key], value)
        elseif target[key] == nil then
            target[key] = value
        end
    end
end

local function MigrateVersion5(database)
    for _, profile in pairs(database.profiles) do
        local overrides = profile.appearanceOverrides
        local windows = overrides and overrides.windows
        local legacySpellBook = windows and windows.SpellBook
        if legacySpellBook then
            windows["PlayerSpells.SpellBook"] =
                windows["PlayerSpells.SpellBook"] or {}
            MergeSparse(windows["PlayerSpells.SpellBook"], legacySpellBook)
            windows.SpellBook = nil
        end
        local legacyCollections = windows and windows["Collections.Journal"]
        if legacyCollections then
            windows.Collections = windows.Collections or {}
            MergeSparse(windows.Collections, legacyCollections)
            windows["Collections.Journal"] = nil
        end
        if windows and not next(windows) then overrides.windows = nil end
        if overrides and not next(overrides) then profile.appearanceOverrides = nil end
    end
end

local function RunMigrations(database, activeProfileTable)
    local version = tonumber(database.version) or 0
    if version < 1 then MigrateVersion1(database, activeProfileTable) end
    if version < 2 then MigrateVersion2(database) end
    if version < 3 then MigrateVersion3(database) end
    if version < 4 then MigrateVersion4(database) end
    if version < 5 then MigrateVersion5(database) end
    if version < 6 then
        for _, profile in pairs(database.profiles) do
            if profile.modules then
                profile.modules.BlizzardProgressBars = nil
                if not next(profile.modules) then profile.modules = nil end
            end
            if profile.moduleOptions then
                profile.moduleOptions.BlizzardProgressBars = nil
                if not next(profile.moduleOptions) then profile.moduleOptions = nil end
            end
        end
    end
    if version < 7 then
        for _, profile in pairs(database.profiles) do
            if profile.theme then
                profile.appearance = profile.appearance or {}
                MergeSparse(profile.appearance, profile.theme)
                profile.theme = nil
            end
        end
    end
    if version < CURRENT_DATABASE_VERSION then
        database.version = CURRENT_DATABASE_VERSION
    end
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
    RunMigrations(database, database.profiles[profileName])
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

function NSkin:RemoveModuleOption(moduleName, key)
    local profile = self:GetProfile()
    local options = profile.moduleOptions
    local moduleOptions = options and options[moduleName]
    if not moduleOptions then return false end
    local changed = moduleOptions[key] ~= nil
    moduleOptions[key] = nil
    if not next(moduleOptions) then options[moduleName] = nil end
    if not next(options) then profile.moduleOptions = nil end
    return changed
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

    if name == self:GetProfileName() then return true end

    local characterKey = GetCharacterKey()
    if characterKey then database.profileKeys[characterKey] = name end
    activeProfile = name
    self:NotifyProfileChanged()
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
    local isActive = name == self:GetProfileName()

    database.profiles[name] = nil
    for characterKey, profileName in pairs(database.profileKeys) do
        if profileName == name then database.profileKeys[characterKey] = DEFAULT_PROFILE end
    end
    if isActive then
        activeProfile = DEFAULT_PROFILE
        self:NotifyProfileChanged()
    end
    return true
end

function NSkin:ResetProfile(name)
    if name == nil then
        name = self:GetProfileName()
    else
        name = NormalizeProfileName(name)
        if not name then return false, "A valid profile name is required." end
    end
    local profiles = self:GetDatabase().profiles
    if not profiles[name] then return false, "That profile does not exist." end
    local isActive = name == self:GetProfileName()
    profiles[name] = {}
    if isActive then self:NotifyProfileChanged() end
    return true
end

function NSkin:NotifyProfileChanged()
    if type(_G.ReloadUI) == "function" then _G.ReloadUI() end
end
