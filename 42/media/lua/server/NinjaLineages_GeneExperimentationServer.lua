require "NinjaLineages_Progression"
require "NinjaLineages_Utils"
require "NinjaLineages_Balance"
require "NinjaLineages_Traits"
require "disciplines/NinjaLineages_CorpseUtils"
require "disciplines/medicine/NinjaLineages_MedicineUtils"
require "NinjaLineages_ExperimentalSurgeryServer"

NinjaLineages = NinjaLineages or {}
NinjaLineages.GeneExperimentationServer = NinjaLineages.GeneExperimentationServer or {}

local ServerLogic = NinjaLineages.GeneExperimentationServer
local MedicineUtils = NinjaLineages.MedicineUtils
local consts = NinjaLineages.Balance.GeneExperimentation

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

-- Handle Zombie Ninja Mutation Roll
local function handleRollZombieNinja(player, args)
    local zombieId = args and args.zombieId
    if not zombieId then return end
    local zombie = ServerLogic.getZombieByOnlineID(zombieId)
    if zombie then
        local modData = zombie:getModData()
        if not modData.zombieNinjaRolled then
            modData.zombieNinjaRolled = true
            local chance = SandboxVars.NinjaLineages
                and SandboxVars.NinjaLineages.ZombieNinjaChance
                or consts.ZOMBIE_NINJA_CHANCE_DEFAULT
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
        if zombie:isKnockedDown() or zombie:isFalling() or zombie:isProne() or zombie:isGettingUp() then return end
        local modData = zombie:getModData()
        if modData.isZombieNinja then
            local now = NinjaLineages.Utils.Time.gameMinutes()
            local lastDash = modData.lastZombieDashTime or 0
            if now - lastDash >= NinjaLineages.Balance.getCooldown("DASH") then
                modData.lastZombieDashTime = now
                sendServerCommand("NinjaLineages", "executeZombieDash", { zombieId = zombieId })
            end
        end
    end
end

local recentZombieNinjaDeaths = {}

local function getDeathKey(x, y, z)
    return tostring(math.floor(x or 0)) .. ":" .. tostring(math.floor(y or 0)) .. ":" .. tostring(math.floor(z or 0))
end

local function rememberZombieNinjaDeath(zombie)
    if not zombie then return end
    local modData = zombie:getModData()
    if not modData or modData.isZombieNinja ~= true then return end
    recentZombieNinjaDeaths[getDeathKey(zombie:getX(), zombie:getY(), zombie:getZ())] = NinjaLineages.Utils.Time.gameMinutes()
end

local function markSpawnedZombieNinjaCorpse(body)
    if not body or not instanceof(body, "IsoDeadBody") then return end
    local key = getDeathKey(body:getX(), body:getY(), body:getZ())
    local deathAt = recentZombieNinjaDeaths[key]
    if not deathAt then return end
    if NinjaLineages.Utils.Time.gameMinutes() - deathAt
            > consts.Extraction.CORPSE_FRESHNESS_WINDOW_MINUTES then
        recentZombieNinjaDeaths[key] = nil
        return
    end

    local modData = body:getModData()
    modData.zombieNinjaRolled = true
    modData.isZombieNinja = true
    recentZombieNinjaDeaths[key] = nil
end

Events.OnZombieDead.Add(rememberZombieNinjaDeath)

-- Server completion logic for corpse experiments (called from singleplayer or server command handler)
function ServerLogic.completeExperiment(player, corpse, actionId)
    if not player or not corpse then return false end
    markSpawnedZombieNinjaCorpse(corpse)
    local modData = corpse:getModData()
    if modData.experimented then return false end
    
    local isZombieNinja = modData.isZombieNinja == true
    if not isZombieNinja then
        local key = getDeathKey(corpse:getX(), corpse:getY(), corpse:getZ())
        if recentZombieNinjaDeaths[key] then
            modData.isZombieNinja = true
            isZombieNinja = true
        end
    end
    if not isZombieNinja then return false end
    
    local data = NinjaLineages.getNLData(player)
    
    if actionId == "Crude Chakra Autopsy" then
        if not NinjaLineages.Progression.isDisciplineLocked(player, "gene_experimentation") then return false end
        
        -- Mark as experimented
        modData.experimented = true
        
        -- Unlock & Reveal discipline
        data.visibleDisciplines = data.visibleDisciplines or {}
        data.visibleDisciplines["gene_experimentation"] = true
        data.unlockedDisciplines = data.unlockedDisciplines or {}
        data.unlockedDisciplines["gene_experimentation"] = true
        NinjaLineages.transmitPlayerData(player)
        
        -- Send feedback message
        MedicineUtils.notifyPlayer(player, "UI_NL_GeneExperimentationUnlocked")
    
    elseif actionId == "Extract Blood Sample" then
        if not NinjaLineages.Progression.isCompleted(player, "blood_extraction") then return false end
        
        modData.experimented = true
        local item = instanceItem("Base.NL_BloodSample")
        if item then
            NinjaLineages.Utils.Inventory.addItemToPlayer(player, item)
        end
        
    elseif actionId == "Extract Ocular Tissue" then
        if not NinjaLineages.Progression.isCompleted(player, "ocular_extraction") then return false end
        
        modData.experimented = true
        local item = instanceItem("Base.NL_OcularTissueSample")
        if item then
            local eyeType = ZombRand(0, 2) == 0 and "sharingan" or "byakugan"
            local freshness = MedicineUtils.rollSampleFreshness()
            item:getModData().eyeType = eyeType
            MedicineUtils.applyItemFreshness(item, freshness)
            local typeName = eyeType == "sharingan" and getText("UI_NL_Ability_Sharingan_Name") or getText("UI_NL_Ability_Byakugan_Name")
            item:setName(getText("UI_item_NL_OcularTissueSample") .. " (" .. typeName .. ")")
            NinjaLineages.Utils.Inventory.addItemToPlayer(player, item)
        end
        
    elseif actionId == "Extract Gene Sample" then
        if not NinjaLineages.Progression.isCompleted(player, "gene_extraction") then return false end
        
        modData.experimented = true
        local item = instanceItem("Base.NL_GeneSample")
        if item then
            local freshness = MedicineUtils.rollSampleFreshness()
            MedicineUtils.applyItemFreshness(item, freshness)
            NinjaLineages.Utils.Inventory.addItemToPlayer(player, item)
        end
    else
        return false
    end
    
    NinjaLineages.transmitPlayerData(player)
    return true
end

-- Handle Complete Corpse Experiment
local function handleCompleteCorpseExperiment(player, args)
    local corpseId = args and args.corpse
    local actionId = args and args.actionId
    if not corpseId or not actionId then return end
    
    local corpse = NinjaLineages.CorpseUtils.getCorpseFromIdentifier(corpseId)
    if corpse then
        -- Validate player distance to corpse using the shared extraction range.
        local dx = player:getX() - corpse:getX()
        local dy = player:getY() - corpse:getY()
        local radius = NinjaLineages.Balance.getRadius(
            consts.Extraction.CORPSE_VALIDATION_RADIUS_TIER
        )
        if (dx * dx + dy * dy) <= (radius * radius) then
            local completed = ServerLogic.completeExperiment(player, corpse, actionId)
            
            if completed then
                -- Broadcast only state that the authoritative mutation accepted.
                sendServerCommand("NinjaLineages", "syncCorpseState", {
                    x = corpseId.x,
                    y = corpseId.y,
                    z = corpseId.z,
                    index = corpseId.index,
                    zombieId = corpseId.zombieId,
                    isZombie = corpseId.isZombie,
                    experimented = corpse:getModData().experimented == true
                })
            end
        end
    end
end

-- Client Command Router for Corpse Experiments and Zombie Ninjas
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

NinjaLineages.addEventOnce("server.geneExperimentation.onClientCommand", Events.OnClientCommand, onClientCommand)
