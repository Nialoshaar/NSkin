local ADDON_NAME, NSkin = ...

NSkin.name = ADDON_NAME
NSkin.modules = NSkin.modules or {}

NSkin.moduleDefinitions = {
    { key = "BlizzardProgressBars", label = "Progress Bars" },
    { key = "EncounterJournal", label = "Adventure Journal" },
    { key = "ToyBox", label = "Collections (Toy Box and Heirlooms)" },
    { key = "SpellBook", label = "Spellbook" },
}

local function GetDatabase()
    _G.NSkinDB = _G.NSkinDB or {}
    return _G.NSkinDB
end

function NSkin:IsModuleEnabled(name)
    local modules = GetDatabase().modules
    return modules and modules[name] == true or false
end

function NSkin:SetModuleEnabled(name, enabled)
    local database = GetDatabase()
    database.modules = database.modules or {}
    database.modules[name] = enabled == true
end

local eventFrame = CreateFrame("Frame")
local callbacks = {}

function NSkin:NewModule(name)
    assert(type(name) == "string" and name ~= "", "A module name is required")
    assert(not self.modules[name], "Module already exists: " .. name)

    local module = { name = name }
    self.modules[name] = module
    return module
end

function NSkin:RegisterEvent(event, callback)
    assert(type(callback) == "function", "Event callback must be a function")

    local handlers = callbacks[event]
    if not handlers then
        handlers = {}
        callbacks[event] = handlers
        eventFrame:RegisterEvent(event)
    end

    handlers[#handlers + 1] = callback
end

function NSkin:Print(message)
    print(("|cff33aaff%s:|r %s"):format(self.name, tostring(message)))
end

eventFrame:SetScript("OnEvent", function(_, event, ...)
    local handlers = callbacks[event]
    if not handlers then return end

    for i = 1, #handlers do
        handlers[i](event, ...)
    end
end)
