local ADDON_NAME, NSkin = ...

NSkin.name = ADDON_NAME
NSkin.modules = NSkin.modules or {}

NSkin.moduleDefinitions = {
    { key = "BlizzardProgressBars", label = "Progress Bars", defaultEnabled = false },
    { key = "EncounterJournal", label = "Adventure Journal", defaultEnabled = false },
    { key = "Collections", label = "Collections", defaultEnabled = false },
    { key = "SpellBook", label = "Spellbook", defaultEnabled = false },
}

NSkin.moduleDefinitionByKey = {}
for i = 1, #NSkin.moduleDefinitions do
    local definition = NSkin.moduleDefinitions[i]
    NSkin.moduleDefinitionByKey[definition.key] = definition
end

local function SafeCall(callback, ...)
    local ok, result = pcall(callback, ...)
    if not ok then
        local errorHandler = _G.geterrorhandler and _G.geterrorhandler()
        if errorHandler then pcall(errorHandler, result) end
    end
    return ok, result
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
local windowSkins = {}
local pendingWindowAddons = {}
local fallbackWindowEventRegistered = false
local MAX_WINDOW_SKIN_RETRIES = 3

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

local function IsAddOnLoaded(addonName)
    if _G.C_AddOns and _G.C_AddOns.IsAddOnLoaded then
        return _G.C_AddOns.IsAddOnLoaded(addonName)
    end
    return _G.IsAddOnLoaded and _G.IsAddOnLoaded(addonName) or false
end

local function ExecuteWindowSkin(definition)
    if not NSkin:IsModuleEnabled(definition.module) then return false end
    return definition.apply() == true
end

local ApplyWindowSkin

local function ScheduleWindowSkinRetry(definition)
    if definition.applied
        or definition.retryScheduled
        or not NSkin:IsModuleEnabled(definition.module)
        or (definition.retryCount or 0) >= MAX_WINDOW_SKIN_RETRIES
        or not _G.C_Timer
        or type(_G.C_Timer.After) ~= "function"
    then
        return
    end

    definition.retryCount = (definition.retryCount or 0) + 1
    definition.retryScheduled = true
    _G.C_Timer.After(0, function()
        definition.retryScheduled = false
        ApplyWindowSkin(definition)
    end)
end

ApplyWindowSkin = function(definition)
    if definition.applied or definition.applying then return end
    definition.applying = true
    local ok, applied = SafeCall(ExecuteWindowSkin, definition)
    definition.applied = ok and applied == true
    definition.applying = false
    if definition.applied then
        definition.retryCount = nil
    else
        ScheduleWindowSkinRetry(definition)
    end
end

local function PrepareWindowSkin(definition)
    if definition.prepared then return true end
    if definition.prepare and not SafeCall(definition.prepare) then return false end
    definition.prepared = true
    return true
end

local function StartWindowSkin(definition)
    if not PrepareWindowSkin(definition) then return end
    if not definition.addon or IsAddOnLoaded(definition.addon) then
        ApplyWindowSkin(definition)
        return
    end

    if _G.EventUtil and _G.EventUtil.ContinueOnAddOnLoaded then
        _G.EventUtil.ContinueOnAddOnLoaded(definition.addon, function()
            ApplyWindowSkin(definition)
        end)
        return
    end

    pendingWindowAddons[definition.addon] = pendingWindowAddons[definition.addon] or {}
    local pending = pendingWindowAddons[definition.addon]
    pending[#pending + 1] = definition
    if not fallbackWindowEventRegistered then
        fallbackWindowEventRegistered = true
        NSkin:RegisterEvent("ADDON_LOADED", function(_, addonName)
            local definitions = pendingWindowAddons[addonName]
            if not definitions then return end
            pendingWindowAddons[addonName] = nil
            for i = 1, #definitions do ApplyWindowSkin(definitions[i]) end
        end)
    end
end

function NSkin:RegisterWindowSkin(definition)
    if type(definition) ~= "table"
        or type(definition.module) ~= "string"
        or not self.moduleDefinitionByKey[definition.module]
        or type(definition.apply) ~= "function"
    then
        return false
    end

    local key = definition.key or definition.module
    if windowSkins[key] then return false end
    windowSkins[key] = definition
    self:RegisterModuleInitializer(definition.module, function()
        StartWindowSkin(definition)
    end)
    return true
end

function NSkin:Print(message)
    print(("|cff33aaff%s:|r %s"):format(self.name, tostring(message)))
end

local function ExecuteModuleInitializer(initializer)
    if NSkin:IsModuleEnabled(initializer.name) then initializer.callback() end
end

eventFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" and not modulesStarted and (...) == ADDON_NAME then
        modulesStarted = true

        for i = 1, #moduleInitializers do
            SafeCall(ExecuteModuleInitializer, moduleInitializers[i])
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
        SafeCall(handlers[i], event, ...)
    end
end)

-- SavedVariables are guaranteed to be available when our ADDON_LOADED fires.
-- Module files can therefore register cheap initializers without accidentally
-- reading their enabled state too early during file loading.
eventFrame:RegisterEvent("ADDON_LOADED")
