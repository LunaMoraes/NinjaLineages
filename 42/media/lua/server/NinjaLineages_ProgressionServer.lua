require "NinjaLineages_Progression"
require "NinjaLineages_Balance"
require "NinjaLineages_Utils"
require "disciplines/jinchuuriki/NinjaLineages_BijuuDefinitions"
require "disciplines/jinchuuriki/NinjaLineages_BijuuState"
require "jinchuuriki/NinjaLineages_BijuuRegistryServer"
require "jinchuuriki/NinjaLineages_BijuuBossServer"

NinjaLineages = NinjaLineages or {}
NinjaLineages.ProgressionServer = NinjaLineages.ProgressionServer or {}

local ProgressionServer = NinjaLineages.ProgressionServer
local Progression = NinjaLineages.Progression
local Definitions = NinjaLineages.BijuuDefinitions
local BijuuState = NinjaLineages.BijuuState
local Registry = NinjaLineages.BijuuRegistryServer
local BossServer = NinjaLineages.BijuuBossServer

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

local function isEncounterState(state)
    return state == BijuuState.WILD_ACTIVE
        or state == BijuuState.BOSS_ACTIVE
        or state == BijuuState.SEALING
end

local function distanceTo(player, x, y, z)
    if not player or type(x) ~= "number" or type(y) ~= "number" then return nil end
    local playerZ = player:getZ()
    if type(z) == "number" and math.abs(playerZ - z) >= 1.5 then return nil end
    local dx, dy = player:getX() - x, player:getY() - y
    return math.sqrt(dx * dx + dy * dy)
end

function ProgressionServer.tryDiscoverJinchuuriki(player, args)
    if not NinjaLineages.Utils.isLivePlayer(player) then return false, "invalid_player" end

    local bijuuId = args and args.bijuuId
    local runtimeId = args and args.runtimeId
    if not Definitions.isValidId(bijuuId) or type(runtimeId) ~= "string" then
        return false, "invalid_encounter"
    end

    local state = Registry.getBijuuState(bijuuId)
    if not isEncounterState(state) then return false, "inactive_bijuu" end

    local runtime = BossServer.getActiveBossSnapshot(bijuuId)
    if not runtime or runtime.runtimeId ~= runtimeId then
        return false, "runtime_mismatch"
    end

    local radius = NinjaLineages.Balance.Jinchuuriki.Discovery.RADIUS
    local distance = distanceTo(player, runtime.x, runtime.y, runtime.z)
    if not distance or distance > radius then return false, "out_of_range" end

    local jinchuuriki = Progression.getJinchuurikiData(player)
    if not jinchuuriki then return false, "missing_player_data" end
    if jinchuuriki.discovered == true then
        local changed = Progression.refreshJinchuurikiDiscipline(player)
        if changed then NinjaLineages.transmitPlayerData(player) end
        return true, "already_discovered", false
    end

    jinchuuriki.discovered = true
    local _, _, unlocked = Progression.refreshJinchuurikiDiscipline(player)
    NinjaLineages.transmitPlayerData(player)
    notifyPlayer(player, unlocked
        and "UI_NL_Jinchuuriki_DiscoveredUnlocked"
        or "UI_NL_Jinchuuriki_SealingRequired")
    return true, "discovered", true
end

local function locatorStatus(state)
    if state == BijuuState.SEALED_VESSEL or state == BijuuState.SEALED_PLAYER then
        return "sealed"
    elseif state == BijuuState.RESPAWNING then
        return "unknown"
    end
    return "unavailable"
end

local function validWorldPosition(world)
    return type(world) == "table"
        and type(world.x) == "number" and world.x == world.x
        and type(world.y) == "number" and world.y == world.y
        and (world.z == nil or (type(world.z) == "number" and world.z == world.z))
end

function ProgressionServer.getBijuuLocatorSnapshot(player)
    if not NinjaLineages.Utils.isLivePlayer(player) then return nil, "invalid_player" end
    if not Progression.isCompleted(player, "tailed_beast_locator") then
        return nil, "locator_locked"
    end

    local entries = {}
    for _, bijuuId in ipairs(Definitions.Order) do
        local definition = Definitions.get(bijuuId)
        local record = Registry.getRecord(bijuuId)
        local state = record and record.state
        local entry = {
            bijuuId = bijuuId,
            tails = definition.tails,
            status = locatorStatus(state),
        }

        if state == BijuuState.WILD_DORMANT and validWorldPosition(record.world) then
            entry.status = "trackable"
            entry.x, entry.y, entry.z = record.world.x, record.world.y, record.world.z or 0
        elseif isEncounterState(state) then
            local runtime = BossServer.getActiveBossSnapshot(bijuuId)
            if runtime and validWorldPosition(runtime) then
                entry.status = "trackable"
                entry.x, entry.y, entry.z = runtime.x, runtime.y, runtime.z or 0
            else
                entry.status = "unknown"
            end
        end
        table.insert(entries, entry)
    end

    return {
        generatedAtGameMinutes = NinjaLineages.Utils.Time.gameMinutes(),
        entries = entries,
    }, "ok"
end

local function handleJinchuurikiDiscovery(player, args)
    local ok, reason, discovered = ProgressionServer.tryDiscoverJinchuuriki(player, args)
    sendState(player, "jinchuurikiDiscoveryResult", {
        ok = ok == true,
        reason = reason,
        discovered = discovered == true,
        bijuuId = args and args.bijuuId,
        runtimeId = args and args.runtimeId,
        playerOnlineId = player.getOnlineID and player:getOnlineID() or -1,
    })
    if ok then sendState(player, "progressionUpdated") end
end

local function handleBijuuLocatorRequest(player)
    local snapshot, reason = ProgressionServer.getBijuuLocatorSnapshot(player)
    sendState(player, "bijuuLocatorSnapshot", {
        ok = snapshot ~= nil,
        reason = reason,
        playerOnlineId = player.getOnlineID and player:getOnlineID() or -1,
        generatedAtGameMinutes = snapshot and snapshot.generatedAtGameMinutes or nil,
        entries = snapshot and snapshot.entries or {},
    })
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
    elseif command == "claimJinchuurikiDiscovery" then
        handleJinchuurikiDiscovery(player, args)
    elseif command == "requestBijuuLocator" then
        handleBijuuLocatorRequest(player)
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
