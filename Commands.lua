local _, NSkin = ...

local function GetModule(name)
    return NSkin.modules and NSkin.modules[name]
end

local function RunModuleMethod(moduleName, methodName, unavailableMessage)
    local module = GetModule(moduleName)
    local method = module and module[methodName]
    if type(method) ~= "function" then
        NSkin:Print(unavailableMessage)
        return false
    end

    method(module)
    return true
end

local commands = {}

commands.rescan = function()
    if RunModuleMethod(
        "BlizzardProgressBars",
        "Scan",
        "Progress bar rescanning is unavailable."
    ) then
        NSkin:Print("progress bars rescanned.")
    end
end

commands.debug = function()
    RunModuleMethod(
        "BlizzardProgressBars",
        "Debug",
        "Progress bar diagnostics are unavailable."
    )
end

commands.journaldebug = function()
    RunModuleMethod(
        "EncounterJournal",
        "Debug",
        "Encounter Journal diagnostics are unavailable."
    )
end

local function HandleSlashCommand(message)
    local command = (message or ""):lower():match("^%s*(.-)%s*$")
    if command == "" then
        if NSkin.ToggleOptions then
            NSkin:ToggleOptions()
        else
            NSkin:Print("Options are unavailable.")
        end
        return
    end

    local handler = commands[command]
    if handler then
        handler()
        return
    end

    NSkin:Print("commands: /nskin, /nskin rescan, /nskin debug, /nskin journaldebug")
end

SLASH_NSKIN1 = "/nskin"
SlashCmdList.NSKIN = HandleSlashCommand
