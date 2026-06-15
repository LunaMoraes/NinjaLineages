require "TimedActions/ISBaseTimedAction"
require "NinjaLineages_Progression"
require "NinjaLineages_Utils"

NinjaLineages = NinjaLineages or {}
NinjaLineages.GeneExperimentationClient = NinjaLineages.GeneExperimentationClient or {}

local ClientLogic = NinjaLineages.GeneExperimentationClient
local zombieMovements = {}

-- Helper functions for corpse identification
local function getCorpseIdentifier(corpse)
    local x = corpse:getX()
    local y = corpse:getY()
    local z = corpse:getZ()
    local sq = corpse:getSquare()
    local index = -1
    if sq then
        local deadBodies = sq:getDeadBodys()
        if deadBodies then
            for i = 0, deadBodies:size() - 1 do
                if deadBodies:get(i) == corpse then
                    index = i
                    break
                end
            end
        end
    end
    local isZombie = instanceof(corpse, "IsoZombie")
    local zombieId = isZombie and corpse:getOnlineID() or nil
    return { x = x, y = y, z = z, index = index, zombieId = zombieId, isZombie = isZombie }
end

local function getCorpseFromIdentifier(args)
    if not args then return nil end
    if args.isZombie and args.zombieId then
        local zombies = getCell() and getCell():getZombieList()
        if zombies then
            for i = 0, zombies:size() - 1 do
                local z = zombies:get(i)
                if z and z:getOnlineID() == args.zombieId then
                    return z
                end
            end
        end
        return nil
    end
    local sq = getCell():getGridSquare(args.x, args.y, args.z)
    if not sq then return nil end
    local deadBodies = sq:getDeadBodys()
    if deadBodies and args.index >= 0 and args.index < deadBodies:size() then
        return deadBodies:get(args.index)
    end
    return nil
end

-- Timed Action Definition
NLCorpseExperimentAction = ISBaseTimedAction:derive("NLCorpseExperimentAction")

function NLCorpseExperimentAction:isValid()
    return self.character and not self.character:isDead() and self.corpse and not self.corpse:getModData().experimented
end

function NLCorpseExperimentAction:start()
    self:setActionAnim("Loot")
    self:setOverrideHandDriven(true)
end

function NLCorpseExperimentAction:stop()
    ISBaseTimedAction.stop(self)
end

function NLCorpseExperimentAction:perform()
    if isClient and isClient() then
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
    o.corpseId = getCorpseIdentifier(corpse)
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
    
    local maxTime = 900 - (docLevel * 60)
    maxTime = math.max(300, math.min(900, maxTime))
    
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
    
    local modData = corpse:getModData()
    if not modData.isZombieNinja or modData.experimented then return end
    
    -- Add sub-menu options based on player progression
    local subMenu = nil
    
    -- Crude Chakra Autopsy option
    if NinjaLineages.Progression.isDisciplineLocked(player, "gene_experimentation") then
        subMenu = NinjaLineages.UI.getOrCreateWorldSubMenu(context)
        subMenu:addOption(getText("UI_NL_CorpseAutopsyOption"), player, startExperimentAction, corpse, "Crude Chakra Autopsy")
    else
        -- Check unlocked extraction nodes
        local showMenu = false
        local canExtractBlood = NinjaLineages.Progression.isCompleted(player, "blood_extraction")
        local canExtractOcular = NinjaLineages.Progression.isCompleted(player, "ocular_extraction")
        local canExtractGene = NinjaLineages.Progression.isCompleted(player, "gene_extraction")
        
        if canExtractBlood or canExtractOcular or canExtractGene then
            subMenu = NinjaLineages.UI.getOrCreateWorldSubMenu(context)
            
            if canExtractBlood then
                subMenu:addOption(getText("UI_NL_ExtractBloodOption"), player, startExperimentAction, corpse, "Extract Blood Sample")
            end
            if canExtractOcular then
                subMenu:addOption(getText("UI_NL_ExtractOcularOption"), player, startExperimentAction, corpse, "Extract Ocular Tissue")
            end
            if canExtractGene then
                subMenu:addOption(getText("UI_NL_ExtractGeneOption"), player, startExperimentAction, corpse, "Extract Gene Sample")
            end
        end
    end
end

-- Start Zombie Dash locally
local function startZombieDash(zombie)
    local target = zombie:getTarget()
    if not target then return end
    
    local dx = target:getX() - zombie:getX()
    local dy = target:getY() - zombie:getY()
    local dist = math.sqrt(dx * dx + dy * dy)
    if dist <= 0 then return end
    
    local dirX = dx / dist
    local dirY = dy / dist
    
    local now = NinjaLineages.Utils.Time.gameMinutes()
    local duration = 0.2 -- BURST duration
    local distance = 3.0 -- Shortened distance
    
    zombieMovements[zombie] = {
        startedAt = now,
        endsAt = now + duration,
        directionX = dirX,
        directionY = dirY,
        distance = distance,
        travelled = 0,
    }
end

-- Update Zombie dash tick
local function updateZombieDash(zombie)
    local movement = zombieMovements[zombie]
    if not movement then return end
    
    local now = NinjaLineages.Utils.Time.gameMinutes()
    local duration = movement.endsAt - movement.startedAt
    local progress = duration > 0 and math.min(1, math.max(0, (now - movement.startedAt) / duration)) or 1
    local targetDistance = movement.distance * progress
    local stepDistance = 0.25
    
    while movement.travelled < targetDistance do
        local distance = math.min(stepDistance, targetDistance - movement.travelled)
        local nextX = zombie:getX() + (movement.directionX * distance)
        local nextY = zombie:getY() + (movement.directionY * distance)
        
        local cell = getCell()
        local currentSquare = cell:getGridSquare(zombie:getX(), zombie:getY(), zombie:getZ())
        local nextSquare = cell:getGridSquare(nextX, nextY, zombie:getZ())
        if not currentSquare or not nextSquare or nextSquare:isBlockedTo(currentSquare) then
            zombieMovements[zombie] = nil
            break
        end
        
        zombie:setX(nextX)
        zombie:setY(nextY)
        movement.travelled = movement.travelled + distance
    end
    
    if zombieMovements[zombie] and progress >= 1 then
        zombieMovements[zombie] = nil
    end
end

-- Zombie Update loop (aggression checking + dash update)
local function onZombieUpdate(zombie)
    if not zombie or zombie:isDead() then
        zombieMovements[zombie] = nil
        return
    end
    
    -- 1. Aggression / Mutation Check
    local target = zombie:getTarget()
    if target and instanceof(target, "IsoPlayer") then
        local modData = zombie:getModData()
        if not modData.zombieNinjaRolled then
            if isClient and isClient() then
                sendClientCommand(getPlayer(), "NinjaLineages", "rollZombieNinja", { zombieId = zombie:getOnlineID() })
                modData.zombieNinjaRolled = true
            else
                -- Singleplayer
                modData.zombieNinjaRolled = true
                local chance = SandboxVars.NinjaLineages and SandboxVars.NinjaLineages.ZombieNinjaChance or 20
                if ZombRand(0, 100) < chance then
                    modData.isZombieNinja = true
                else
                    modData.isZombieNinja = false
                end
            end
        end
        
        -- 2. Zombie Ninja Dash Check
        if modData.isZombieNinja and not zombieMovements[zombie] then
            local distance = zombie:DistTo(target)
            if distance >= 2.0 and distance <= 6.0 then
                local now = NinjaLineages.Utils.Time.gameMinutes()
                local lastDash = modData.lastZombieDashTime or 0
                -- 10 seconds cooldown = 0.16 in-game minutes
                if now - lastDash >= 0.16 then
                    if isClient and isClient() then
                        sendClientCommand(getPlayer(), "NinjaLineages", "zombieDashRequest", { zombieId = zombie:getOnlineID() })
                    else
                        -- Singleplayer
                        modData.lastZombieDashTime = now
                        startZombieDash(zombie)
                    end
                end
            end
        end
    end
    
    -- 3. Update active dash
    if zombieMovements[zombie] then
        updateZombieDash(zombie)
    end
end

-- Server Command Listener
local function onServerCommand(module, command, args)
    if module ~= "NinjaLineages" then return end
    
    if command == "syncZombieNinjaState" then
        local zombieId = args and args.zombieId
        local isZombieNinja = args and args.isZombieNinja
        if zombieId then
            local zombies = getCell() and getCell():getZombieList()
            if zombies then
                for i = 0, zombies:size() - 1 do
                    local z = zombies:get(i)
                    if z and z:getOnlineID() == zombieId then
                        local modData = z:getModData()
                        modData.zombieNinjaRolled = true
                        modData.isZombieNinja = isZombieNinja
                        break
                    end
                end
            end
        end
    elseif command == "executeZombieDash" then
        local zombieId = args and args.zombieId
        if zombieId then
            local zombies = getCell() and getCell():getZombieList()
            if zombies then
                for i = 0, zombies:size() - 1 do
                    local z = zombies:get(i)
                    if z and z:getOnlineID() == zombieId then
                        startZombieDash(z)
                        break
                    end
                end
            end
        end
    elseif command == "syncCorpseState" then
        local corpse = getCorpseFromIdentifier(args)
        if corpse then
            corpse:getModData().experimented = true
        end
    elseif command == "geneExperimentationMessage" then
        local player = getPlayer()
        if player and args and args.textKey then
            player:Say(getText(args.textKey))
        end
    end
end

-- Event Registrations
NinjaLineages.addEventOnce("client.geneExperimentation.onFillWorldObjectContextMenu", Events.OnFillWorldObjectContextMenu, addGeneExperimentationContextMenu)
NinjaLineages.addEventOnce("client.geneExperimentation.onZombieUpdate", Events.OnZombieUpdate, onZombieUpdate)
NinjaLineages.addEventOnce("client.geneExperimentation.onServerCommand", Events.OnServerCommand, onServerCommand)
