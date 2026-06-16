require "NinjaLineages_Progression"
require "NinjaLineages_Utils"

NinjaLineages = NinjaLineages or {}
NinjaLineages.ProgressionServer = NinjaLineages.ProgressionServer or {}

local function sendState(player, command, payload)
    sendServerCommand(player, "NinjaLineages", command, payload or {})
end

local function notifyPlayer(player, textKey)
    if not player or not textKey then return end
    if isServer and isServer() then
        sendState(player, "geneExperimentationMessage", { textKey = textKey })
    else
        player:Say(getText(textKey))
    end
end

local function canUseDebugCommands(player)
    if not (SandboxVars
            and SandboxVars.NinjaLineages
            and SandboxVars.NinjaLineages.DebugMode == true) then
        return false
    end

    local ok, accessLevel = pcall(function() return player:getAccessLevel() end)
    return ok and string.lower(tostring(accessLevel or "")) == "admin"
end

local function handleAward(player, args)
    local source = args and args.source
    local amount = tonumber(args and args.amount) or 0
    if source ~= "chakra" and source ~= "meditation" then return end
    local maximum = NinjaLineages.Balance.Progression.NinjaXP
    if source == "chakra" then
        amount = math.min(amount, maximum.CHAKRA_DAILY_CAP)
    else
        amount = math.min(amount, maximum.MEDITATION_REWARD)
    end
    NinjaLineages.Progression.awardXP(player, source, amount, true)
    sendState(player, "progressionUpdated")
end

local function handleUnlock(player, args)
    local ok, reason = NinjaLineages.Progression.unlockNode(player, args and args.nodeId, args and args.bypass)
    sendState(player, "unlockResult", { ok = ok == true, reason = reason, nodeId = args and args.nodeId })
end

local function handleCompleteTraining(player, args)
    local nodeId = args and args.nodeId
    local itemId = tonumber(args and args.itemId) or -1
    local item = player:getInventory():getItemById(itemId)
    local ok, reason = NinjaLineages.Progression.completeTraining(player, nodeId, item)
    sendState(player, "trainingResult", { ok = ok == true, reason = reason, nodeId = nodeId })
end

local function handleDebugAddXP(player, args)
    if not canUseDebugCommands(player) then
        sendState(player, "debugResult", { ok = false, action = "addXP" })
        return
    end

    local amount = math.min(1000, math.max(0, tonumber(args and args.amount) or 0))
    if amount <= 0 then
        sendState(player, "debugResult", { ok = false, action = "addXP" })
        return
    end

    local current = NinjaLineages.Progression.getNinjaXP(player)
    NinjaLineages.Progression.setNinjaXP(player, current + amount)
    sendState(player, "debugResult", { ok = true, action = "addXP", amount = amount })
end

local function handleDebugToggleBypass(player)
    if not canUseDebugCommands(player) then
        sendState(player, "debugResult", { ok = false, action = "toggleBypass" })
        return
    end

    local data = NinjaLineages.getNLData(player)
    data.bypassTraining = data.bypassTraining ~= true
    NinjaLineages.transmitPlayerData(player)
    sendState(player, "debugResult", {
        ok = true,
        action = "toggleBypass",
        enabled = data.bypassTraining,
    })
end

local function handleDebugToggleAllVisible(player)
    if not canUseDebugCommands(player) then
        sendState(player, "debugResult", { ok = false, action = "toggleAllVisible" })
        return
    end

    local data = NinjaLineages.getNLData(player)
    data.allDisciplinesVisible = data.allDisciplinesVisible ~= true
    NinjaLineages.transmitPlayerData(player)
    sendState(player, "debugResult", {
        ok = true,
        action = "toggleAllVisible",
        enabled = data.allDisciplinesVisible,
    })
end

local function handleDebugToggleAllUnlocked(player)
    if not canUseDebugCommands(player) then
        sendState(player, "debugResult", { ok = false, action = "toggleAllUnlocked" })
        return
    end

    local data = NinjaLineages.getNLData(player)
    data.allDisciplinesUnlocked = data.allDisciplinesUnlocked ~= true
    NinjaLineages.transmitPlayerData(player)
    sendState(player, "debugResult", {
        ok = true,
        action = "toggleAllUnlocked",
        enabled = data.allDisciplinesUnlocked,
    })
end

local function revealGeneExperimentation(player)
    local data = NinjaLineages.getNLData(player)
    data.visibleDisciplines = data.visibleDisciplines or {}
    if data.visibleDisciplines.gene_experimentation == true then return false end

    data.visibleDisciplines.gene_experimentation = true
    NinjaLineages.transmitPlayerData(player)
    notifyPlayer(player, "UI_NL_GeneExperimentationRevealed")
    return true
end

local function onClientCommand(module, command, player, args)
    if module ~= "NinjaLineages" then return end
    if command == "awardNinjaXP" then
        handleAward(player, args)
    elseif command == "unlockNode" then
        handleUnlock(player, args)
    elseif command == "completeTraining" then
        handleCompleteTraining(player, args)
    elseif command == "debugAddNinjaXP" then
        handleDebugAddXP(player, args)
    elseif command == "debugToggleBypass" then
        handleDebugToggleBypass(player)
    elseif command == "debugToggleAllVisible" then
        handleDebugToggleAllVisible(player)
    elseif command == "debugToggleAllUnlocked" then
        handleDebugToggleAllUnlocked(player)
    end
end

local function onZombieDead(zombie)
    local attacker = zombie and zombie:getAttackedBy()
    if attacker and instanceof(attacker, "IsoPlayer") then
        local reward = NinjaLineages.Balance.Progression.NinjaXP.KILL
        NinjaLineages.Progression.awardXP(attacker, "kill", reward, true)
        local modData = zombie:getModData()
        if modData and modData.isZombieNinja == true then
            revealGeneExperimentation(attacker)
        end
        sendState(attacker, "progressionUpdated")
    end
end

Events.OnClientCommand.Add(onClientCommand)
Events.OnZombieDead.Add(onZombieDead)
