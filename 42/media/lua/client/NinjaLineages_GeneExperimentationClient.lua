require "TimedActions/ISBaseTimedAction"
require "NinjaLineages_Progression"
require "NinjaLineages_Utils"
require "NinjaLineages_Balance"
require "disciplines/NinjaLineages_CorpseUtils"

NinjaLineages = NinjaLineages or {}
NinjaLineages.GeneExperimentationClient = NinjaLineages.GeneExperimentationClient or {}

local ClientLogic = NinjaLineages.GeneExperimentationClient
local geneBalance = NinjaLineages.Balance.GeneExperimentation
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
            > geneBalance.Extraction.CORPSE_FRESHNESS_WINDOW_MINUTES then
        recentZombieNinjaDeaths[key] = nil
        return
    end

    local modData = body:getModData()
    modData.zombieNinjaRolled = true
    modData.isZombieNinja = true
    recentZombieNinjaDeaths[key] = nil
end

-- (Corpse identification helpers now in NinjaLineages.CorpseUtils)

-- Timed Action Definition
NLCorpseExperimentAction = ISBaseTimedAction:derive("NLCorpseExperimentAction")

function NLCorpseExperimentAction:isValid()
    return self.character and not self.character:isDead() and self.corpse and not self.corpse:getModData().experimented
end

function NLCorpseExperimentAction:start()
    self:setActionAnim("Loot")
end

function NLCorpseExperimentAction:stop()
    ISBaseTimedAction.stop(self)
end

function NLCorpseExperimentAction:perform()
    if NinjaLineages.isClient() then
        sendClientCommand(self.character, "NinjaLineages", "completeCorpseExperiment", {
            corpse = self.corpseId,
            actionId = self.actionId
        })
    else
        -- Singleplayer
        local ServerLogic = NinjaLineages.GeneExperimentationServer
        if ServerLogic and ServerLogic.completeExperiment then
            ServerLogic.completeExperiment(self.character, self.corpse, self.actionId)
        end
    end
    ISBaseTimedAction.perform(self)
end

function NLCorpseExperimentAction:new(character, corpse, actionId, maxTime)
    local o = {}
    setmetatable(o, self)
    self.__index = self
    o.character = character
    o.corpse = corpse
    o.actionId = actionId
    o.corpseId = NinjaLineages.CorpseUtils.getCorpseIdentifier(corpse)
    o.stopOnWalk = true
    o.stopOnRun = true
    o.maxTime = maxTime
    return o
end

-- Start Timed Action
local function startExperimentAction(player, corpse, actionId)
    local docLevel = 0
    if Perks.Doctor then
        docLevel = player:getPerkLevel(Perks.Doctor)
    elseif Perks.FirstAid then
        docLevel = player:getPerkLevel(Perks.FirstAid)
    end
    
    local extraction = geneBalance.Extraction
    local maxTime = extraction.TIMED_ACTION_MAX
        - (docLevel * extraction.TIMED_ACTION_REDUCTION_PER_DOCTOR_LEVEL)
    maxTime = math.max(
        extraction.TIMED_ACTION_MIN,
        math.min(extraction.TIMED_ACTION_MAX, maxTime)
    )
    
    ISTimedActionQueue.add(NLCorpseExperimentAction:new(player, corpse, actionId, maxTime))
end

-- Context Menu Creation
local function addGeneExperimentationContextMenu(playerNum, context, worldObjects, test)
    local player = getSpecificPlayer(playerNum)
    if not player or player:isDead() then return end
    if test then return true end
    
    local corpse = nil
    for _, obj in ipairs(worldObjects) do
        if instanceof(obj, "IsoDeadBody") then
            corpse = obj
            break
        elseif instanceof(obj, "IsoZombie") and obj:isDead() then
            corpse = obj
            break
        end
    end
    
    if not corpse then
        for _, obj in ipairs(worldObjects) do
            if obj.getSquare and obj:getSquare() then
                local sq = obj:getSquare()
                local deadBodies = sq:getDeadBodys()
                if deadBodies and deadBodies:size() > 0 then
                    corpse = deadBodies:get(0)
                    break
                end
            end
        end
    end
    
    if not corpse then return end
    
    markSpawnedZombieNinjaCorpse(corpse)
    local modData = corpse:getModData()
    if not modData.isZombieNinja or modData.experimented then return end
    
    -- Add surgery options based on player progression.
    local surgeryOptions = {}
    
    -- Crude Chakra Autopsy option
    if NinjaLineages.Progression.isDisciplineLocked(player, "gene_experimentation") then
        table.insert(surgeryOptions, {
            label = getText("UI_NL_CorpseAutopsyOption"),
            actionId = "Crude Chakra Autopsy",
        })
    else
        -- Check unlocked extraction nodes
        local canExtractBlood = NinjaLineages.Progression.isCompleted(player, "blood_extraction")
        local canExtractOcular = NinjaLineages.Progression.isCompleted(player, "ocular_extraction")
        local canExtractGene = NinjaLineages.Progression.isCompleted(player, "gene_extraction")
        
        if canExtractBlood then
            table.insert(surgeryOptions, {
                label = getText("UI_NL_ExtractBloodOption"),
                actionId = "Extract Blood Sample",
            })
        end
        if canExtractOcular then
            table.insert(surgeryOptions, {
                label = getText("UI_NL_ExtractOcularOption"),
                actionId = "Extract Ocular Tissue",
            })
        end
        if canExtractGene then
            table.insert(surgeryOptions, {
                label = getText("UI_NL_ExtractGeneOption"),
                actionId = "Extract Gene Sample",
            })
        end
    end

    if #surgeryOptions == 0 then return end

    local shinobiSubMenu = NinjaLineages.UI.getOrCreateWorldSubMenu(context)
    if not shinobiSubMenu then return end
    local surgeriesSubMenu = NinjaLineages.UI.getOrCreateSubMenu(shinobiSubMenu, getText("UI_NL_CorpseSurgeriesMenu"))
    if not surgeriesSubMenu then return end

    for _, surgeryOption in ipairs(surgeryOptions) do
        surgeriesSubMenu:addOption(surgeryOption.label, player, startExperimentAction, corpse, surgeryOption.actionId)
    end
end

-- Server Command Listener
local function onServerCommand(module, command, args)
    if module ~= "NinjaLineages" then return end
    
    if command == "syncCorpseState" then
        local corpse = NinjaLineages.CorpseUtils.getCorpseFromIdentifier(args)
        if corpse then
            corpse:getModData().experimented = true
        end
    elseif command == "geneExperimentationMessage" then
        local player = nil
        if args and args.casterOnlineId and getPlayerByOnlineID then
            player = getPlayerByOnlineID(args.casterOnlineId)
        end
        if not player then
            player = getPlayer()
        end
        if player and args and args.textKey then
            player:Say(getText(args.textKey))
        end
    end
end

-- Event Registrations
NinjaLineages.addEventOnce("client.geneExperimentation.onFillWorldObjectContextMenu", Events.OnFillWorldObjectContextMenu, addGeneExperimentationContextMenu)
NinjaLineages.addEventOnce("client.geneExperimentation.onZombieDead", Events.OnZombieDead, rememberZombieNinjaDeath)
NinjaLineages.addEventOnce("client.geneExperimentation.onDeadBodySpawn", Events.OnDeadBodySpawn, markSpawnedZombieNinjaCorpse)
NinjaLineages.addEventOnce("client.geneExperimentation.onServerCommand", Events.OnServerCommand, onServerCommand)
