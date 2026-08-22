local ADDON_NAME, NSkin = ...

NSkin.name = ADDON_NAME
NSkin.modules = NSkin.modules or {}

NSkin.moduleDefinitions = {
    { key = "BlizzardProgressBars", label = "Progress Bars" },
    { key = "EncounterJournal", label = "Adventure Journal" },
    { key = "ToyBox", label = "Collections (Toy Box and Heirlooms)" },
    { key = "SpellBook", label = "Spellbook" },
}

function NSkin:IsModuleEnabled(name)
    local modules = self:GetProfile().modules
    return modules and modules[name] == true or false
end

function NSkin:SetModuleEnabled(name, enabled)
    local profile = self:GetProfile()
    profile.modules = profile.modules or {}
    profile.modules[name] = enabled == true
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
