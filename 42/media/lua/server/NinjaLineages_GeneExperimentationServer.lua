require "NinjaLineages_Progression"
require "NinjaLineages_Utils"

NinjaLineages = NinjaLineages or {}
NinjaLineages.GeneExperimentationServer = NinjaLineages.GeneExperimentationServer or {}

local ServerLogic = NinjaLineages.GeneExperimentationServer

local function notifyPlayer(player, textKey)
    if not player or not textKey then return end
    if isServer and isServer() then
        sendServerCommand(player, "NinjaLineages", "geneExperimentationMessage", { textKey = textKey })
    else
        player:Say(getText(textKey))
    end
end

-- Retrieve a zombie by its online ID
function ServerLogic.getZombieByOnlineID(onlineID)
    if not onlineID then return nil end
    local zombies = getCell() and getCell():getZombieList()
    if not zombies then return nil end
    for i = 0, zombies:size() - 1 do
        local zombie = zombies:get(i)
        if zombie and zombie:getOnlineID() == onlineID then
            return zombie
        end
    end
    return nil
end

-- Retrieve a corpse by coordinates and square index
function ServerLogic.getCorpseFromIdentifier(args)
    if not args then return nil end
    if args.isZombie and args.zombieId then
        return ServerLogic.getZombieByOnlineID(args.zombieId)
    end
    local sq = getCell():getGridSquare(args.x, args.y, args.z)
    if not sq then return nil end
    local deadBodies = sq:getDeadBodys()
    if deadBodies and args.index >= 0 and args.index < deadBodies:size() then
        return deadBodies:get(args.index)
    end
    return nil
end

-- Handle Zombie Ninja Mutation Roll
local function handleRollZombieNinja(player, args)
    local zombieId = args and args.zombieId
    if not zombieId then return end
    local zombie = ServerLogic.getZombieByOnlineID(zombieId)
    if zombie then
        local modData = zombie:getModData()
        if not modData.zombieNinjaRolled then
            modData.zombieNinjaRolled = true
            local chance = SandboxVars.NinjaLineages and SandboxVars.NinjaLineages.ZombieNinjaChance or 20
            if ZombRand(0, 100) < chance then
                modData.isZombieNinja = true
            else
                modData.isZombieNinja = false
            end
        end
        sendServerCommand("NinjaLineages", "syncZombieNinjaState", { zombieId = zombieId, isZombieNinja = modData.isZombieNinja })
    end
end

-- Handle Zombie Dash Request
local function handleZombieDashRequest(player, args)
    local zombieId = args and args.zombieId
    if not zombieId then return end
    local zombie = ServerLogic.getZombieByOnlineID(zombieId)
    if zombie then
        local modData = zombie:getModData()
        if modData.isZombieNinja then
            local now = NinjaLineages.Utils.Time.gameMinutes()
            local lastDash = modData.lastZombieDashTime or 0
            -- 10 seconds cooldown = 0.16 in-game minutes
            if now - lastDash >= 0.16 then
                modData.lastZombieDashTime = now
                sendServerCommand("NinjaLineages", "executeZombieDash", { zombieId = zombieId })
            end
        end
    end
end

-- Server completion logic for experiments (called from singleplayer or server command handler)
function ServerLogic.completeExperiment(player, corpse, actionId)
    if not corpse then return end
    local modData = corpse:getModData()
    if modData.experimented then return end
    
    local isZombieNinja = modData.isZombieNinja == true
    if not isZombieNinja then return end
    
    local data = NinjaLineages.getNLData(player)
    
    if actionId == "Crude Chakra Autopsy" then
        if not NinjaLineages.Progression.isDisciplineLocked(player, "gene_experimentation") then return end
        
        -- Mark as experimented
        modData.experimented = true
        
        -- Unlock & Reveal discipline
        data.visibleDisciplines = data.visibleDisciplines or {}
        data.visibleDisciplines["gene_experimentation"] = true
        data.unlockedDisciplines = data.unlockedDisciplines or {}
        data.unlockedDisciplines["gene_experimentation"] = true
        NinjaLineages.transmitPlayerData(player)
        
        -- Send feedback message
        notifyPlayer(player, "UI_NL_GeneExperimentationUnlocked")
    
    elseif actionId == "Extract Blood Sample" then
        if not NinjaLineages.Progression.isCompleted(player, "blood_extraction") then return end
        
        modData.experimented = true
        local item = instanceItem("Base.NL_BloodSample")
        if item then player:getInventory():AddItem(item) end
        
    elseif actionId == "Extract Ocular Tissue" then
        if not NinjaLineages.Progression.isCompleted(player, "ocular_extraction") then return end
        
        modData.experimented = true
        local item = instanceItem("Base.NL_OcularTissueSample")
        if item then player:getInventory():AddItem(item) end
        
    elseif actionId == "Extract Gene Sample" then
        if not NinjaLineages.Progression.isCompleted(player, "gene_extraction") then return end
        
        modData.experimented = true
        local item = instanceItem("Base.NL_GeneSample")
        if item then player:getInventory():AddItem(item) end
    end
    
    NinjaLineages.transmitPlayerData(player)
end

-- Handle Complete Corpse Experiment
local function handleCompleteCorpseExperiment(player, args)
    local corpseId = args and args.corpse
    local actionId = args and args.actionId
    if not corpseId or not actionId then return end
    
    local corpse = ServerLogic.getCorpseFromIdentifier(corpseId)
    if corpse then
        -- Validate player distance to corpse (within 4 tiles)
        local dx = player:getX() - corpse:getX()
        local dy = player:getY() - corpse:getY()
        if (dx * dx + dy * dy) <= 16 then
            ServerLogic.completeExperiment(player, corpse, actionId)
            
            -- Broadcast corpse experiment sync to all clients
            sendServerCommand("NinjaLineages", "syncCorpseState", {
                x = corpseId.x,
                y = corpseId.y,
                z = corpseId.z,
                index = corpseId.index,
                zombieId = corpseId.zombieId,
                isZombie = corpseId.isZombie,
                experimented = true
            })
        end
    end
end

-- Client Command Router
local function onClientCommand(module, command, player, args)
    if module ~= "NinjaLineages" then return end
    
    if command == "rollZombieNinja" then
        handleRollZombieNinja(player, args)
    elseif command == "zombieDashRequest" then
        handleZombieDashRequest(player, args)
    elseif command == "completeCorpseExperiment" then
        handleCompleteCorpseExperiment(player, args)
    end
end

Events.OnClientCommand.Add(onClientCommand)
