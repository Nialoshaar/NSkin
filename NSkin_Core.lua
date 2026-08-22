local ADDON_NAME, NSkin = ...

NSkin.name = ADDON_NAME
NSkin.modules = NSkin.modules or {}

NSkin.moduleDefinitions = {
    { key = "BlizzardProgressBars", label = "Progress Bars", defaultEnabled = false },
    { key = "EncounterJournal", label = "Adventure Journal", defaultEnabled = false },
    { key = "ToyBox", label = "Collections (Toy Box and Heirlooms)", defaultEnabled = false },
    { key = "SpellBook", label = "Spellbook", defaultEnabled = false },
}

NSkin.moduleDefinitionByKey = {}
for i = 1, #NSkin.moduleDefinitions do
    local definition = NSkin.moduleDefinitions[i]
    NSkin.moduleDefinitionByKey[definition.key] = definition
end

function NSkin:GetModuleDefault(name)
    local definition = self.moduleDefinitionByKey[name]
    return definition and definition.defaultEnabled == true or false
end

function NSkin:IsModuleEnabled(name)
    local modules = self:GetProfile().modules
    if modules and modules[name] ~= nil then return modules[name] == true end
    return self:GetModuleDefault(name)
end

function NSkin:SetModuleEnabled(name, enabled)
    local profile = self:GetProfile()
    local value = enabled == true
    local default = self:GetModuleDefault(name)
    if value == default then
        if profile.modules then
            profile.modules[name] = nil
            if not next(profile.modules) then profile.modules = nil end
        end
    else
        profile.modules = profile.modules or {}
        profile.modules[name] = value
    end
end

local eventFrame = CreateFrame("Frame")
local callbacks = {}
local moduleInitializers = {}
local modulesStarted = false

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

function NSkin:RegisterModuleInitializer(name, callback)
    assert(type(name) == "string" and name ~= "", "A module name is required")
    assert(type(callback) == "function", "Module initializer must be a function")

    moduleInitializers[#moduleInitializers + 1] = {
        name = name,
        callback = callback,
    }
end

function NSkin:Print(message)
    print(("|cff33aaff%s:|r %s"):format(self.name, tostring(message)))
end

eventFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" and not modulesStarted and (...) == ADDON_NAME then
        modulesStarted = true

        for i = 1, #moduleInitializers do
            local initializer = moduleInitializers[i]
            if NSkin:IsModuleEnabled(initializer.name) then
                initializer.callback()
            end
        end

        -- ADDON_LOADED is needed by the core only for SavedVariables startup.
        -- Keep it registered only when an enabled module requested callbacks.
        if not callbacks.ADDON_LOADED then
            eventFrame:UnregisterEvent("ADDON_LOADED")
        end
    end

    local handlers = callbacks[event]
    if not handlers then return end

    for i = 1, #handlers do
        handlers[i](event, ...)
    end
end)

-- SavedVariables are guaranteed to be available when our ADDON_LOADED fires.
-- Module files can therefore register cheap initializers without accidentally
-- reading their enabled state too early during file loading.
eventFrame:RegisterEvent("ADDON_LOADED")
