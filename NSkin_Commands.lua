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

commands.journaldebug = function()
    RunModuleMethod(
        "EncounterJournal",
        "Debug",
        "Encounter Journal diagnostics are unavailable."
    )
end

commands.journalresetdebug = function()
    RunModuleMethod(
        "EncounterJournal",
        "DebugResetRestoration",
        "Encounter Journal reset diagnostics are unavailable."
    )
end

commands.journalprofiledebug = function()
    RunModuleMethod(
        "EncounterJournal",
        "DebugProfile",
        "Encounter Journal profile diagnostics are unavailable."
    )
end

commands.skinning = function()
    if type(NSkin.ToggleSkinningMode) == "function" then
        NSkin:ToggleSkinningMode()
    else
        NSkin:Print("Skinning Mode is unavailable.")
    end
end

commands.edit = commands.skinning

commands.resettabs = function()
    if _G.InCombatLockdown and _G.InCombatLockdown() then
        NSkin:Print("Spellbook tabs cannot be reset during combat.")
        return
    end
    if type(NSkin.ResetSpellBookTabPlacements) == "function"
        and NSkin:ResetSpellBookTabPlacements()
    then
        NSkin:Print("Spellbook tab placement overrides cleared.")
    else
        NSkin:Print("Spellbook tab reset is unavailable.")
    end
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

    NSkin:Print("commands: /nskin, /nskin edit, /nskin skinning, /nskin resettabs, /nskin journaldebug, /nskin journalresetdebug, /nskin journalprofiledebug")
end

SLASH_NSKIN1 = "/nskin"
SlashCmdList.NSKIN = HandleSlashCommand
