require "NinjaLineages_Progression"
require "NinjaLineages_Balance"
require "NinjaLineages_Utils"

NinjaLineages = NinjaLineages or {}
NinjaLineages.ProgressionServer = NinjaLineages.ProgressionServer or {}

local function sendState(player, command, payload)
    sendServerCommand(player, "NinjaLineages", command, payload or {})
end

local function notifyPlayer(player, textKey)
    if not player or not textKey then return end
    if NinjaLineages.isServer() then
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

local function isDebugMode()
    return (isDebugEnabled and isDebugEnabled())
        or (SandboxVars and SandboxVars.NinjaLineages and SandboxVars.NinjaLineages.DebugMode == true)
end

local function handleCompleteTraining(player, args)
    local nodeId = args and args.nodeId
    local itemId = tonumber(args and args.itemId) or -1
    local item = player:getInventory():getItemById(itemId)
    local readPages = NinjaLineages.Progression.getTrainingPagesRead(player, nodeId)
    if isDebugMode() then
        print("[DEBUG-NL-TRAINING] server complete node=" .. tostring(nodeId)
            .. " itemId=" .. tostring(itemId)
            .. " serverPages=" .. tostring(readPages))
    end
    local ok, reason = NinjaLineages.Progression.completeTraining(player, nodeId, item)
    if isDebugMode() then
        print("[DEBUG-NL-TRAINING] server complete result node=" .. tostring(nodeId)
            .. " ok=" .. tostring(ok == true)
            .. " reason=" .. tostring(reason))
    end
    sendState(player, "trainingResult", {
        ok = ok == true,
        reason = reason,
        nodeId = nodeId,
        pages = NinjaLineages.Progression.getTrainingPagesRead(player, nodeId),
    })
end

local function handleTrainingProgress(player, args)
    local nodeId = args and args.nodeId
    local itemId = tonumber(args and args.itemId) or -1
    local pages = args and args.pages
    local item = player:getInventory():getItemById(itemId)
    local ok, reason, savedPages, required = NinjaLineages.Progression.setTrainingProgress(player, nodeId, item, pages)
    if isDebugMode() then
        print("[DEBUG-NL-TRAINING] server checkpoint node=" .. tostring(nodeId)
            .. " itemId=" .. tostring(itemId)
            .. " savedPages=" .. tostring(savedPages)
            .. " required=" .. tostring(required)
            .. " ok=" .. tostring(ok == true)
            .. " reason=" .. tostring(reason))
    end
    sendState(player, "trainingProgressResult", {
        ok = ok == true,
        reason = reason,
        nodeId = nodeId,
        pages = savedPages,
        required = required,
    })
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

local function handleDebugCompleteCoreTrees(player)
    if not canUseDebugCommands(player) then
        sendState(player, "debugResult", { ok = false, action = "completeCoreTrees" })
        return
    end

    local completed, rank = NinjaLineages.Progression.completeCoreTrees(player)
    sendState(player, "debugResult", {
        ok = true,
        action = "completeCoreTrees",
        completed = completed,
        rank = rank,
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

local function handleDebugLearnSenninMode(player)
    if not canUseDebugCommands(player) then return end
    local state = NinjaLineages.Progression.getState(player)
    local data = NinjaLineages.getNLData(player)
    if not state or not data then return end

    data.visibleDisciplines = data.visibleDisciplines or {}
    data.visibleDisciplines.sennin_mode = true
    data.unlockedDisciplines = data.unlockedDisciplines or {}
    data.unlockedDisciplines.sennin_mode = true

    if not NinjaLineages.Progression.getChosenContract(player) then
        state.nodes["toad_contract"] = "completed"
    end

    data.sageTrial = data.sageTrial or {}
    local trials = NinjaLineages.Balance.SageMode.Trials
    data.sageTrial.meditationMinutes = math.max(trials.MEDITATION_MINUTES, data.sageTrial.meditationMinutes or trials.MEDITATION_MINUTES)
    data.sageTrial.meleeKills = math.max(trials.TOAD_MELEE_KILLS, data.sageTrial.meleeKills or trials.TOAD_MELEE_KILLS)
    data.sageTrial.rangedKills = math.max(trials.SNAKE_RANGED_KILLS, data.sageTrial.rangedKills or trials.SNAKE_RANGED_KILLS)
    data.sageTrial.healthHealed = math.max(trials.SNAIL_HEALTH_HEALED, data.sageTrial.healthHealed or trials.SNAIL_HEALTH_HEALED)
    data.sageTrial.completed = true
    data.sageTrial.notified = true

    state.nodes["nature_chakra_manipulation"] = "completed"

    NinjaLineages.transmitPlayerData(player)
    sendState(player, "progressionUpdated")
    notifyPlayer(player, "UI_NL_Debug_SenninModeLearned")
end

local function onClientCommand(module, command, player, args)
    if module ~= "NinjaLineages" then return end
    if command == "awardNinjaXP" then
        handleAward(player, args)
    elseif command == "unlockNode" then
        handleUnlock(player, args)
    elseif command == "completeTraining" then
        handleCompleteTraining(player, args)
    elseif command == "trainingProgress" then
        handleTrainingProgress(player, args)
    elseif command == "debugAddNinjaXP" then
        handleDebugAddXP(player, args)
    elseif command == "debugToggleBypass" then
        handleDebugToggleBypass(player)
    elseif command == "debugToggleAllVisible" then
        handleDebugToggleAllVisible(player)
    elseif command == "debugToggleAllUnlocked" then
        handleDebugToggleAllUnlocked(player)
    elseif command == "debugCompleteCoreTrees" then
        handleDebugCompleteCoreTrees(player)
    elseif command == "debugLearnSenninMode" then
        handleDebugLearnSenninMode(player)
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

        local chosen = NinjaLineages.Progression.getChosenContract(attacker)
        if chosen then
            local data = NinjaLineages.getNLData(attacker)
            if data then
                data.sageTrial = data.sageTrial or {}
                local weapon = attacker:getPrimaryHandItem()
                local isRanged = weapon and weapon:isRanged()
                if isRanged then
                    data.sageTrial.rangedKills = (data.sageTrial.rangedKills or 0) + 1
                else
                    data.sageTrial.meleeKills = (data.sageTrial.meleeKills or 0) + 1
                end
                NinjaLineages.transmitPlayerData(attacker)
                NinjaLineages.Progression.checkAndNotifySageTrial(attacker)
            end
        end

        sendState(attacker, "progressionUpdated")
    end
end

NinjaLineages.addEventOnce("server.progression.onClientCommand", Events.OnClientCommand, onClientCommand)
NinjaLineages.addEventOnce("server.progression.onZombieDead", Events.OnZombieDead, onZombieDead)
