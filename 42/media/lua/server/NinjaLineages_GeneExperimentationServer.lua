require "NinjaLineages_Progression"
require "NinjaLineages_Utils"
require "NinjaLineages_Balance"
require "NinjaLineages_Constants"
require "NinjaLineages_Traits"
require "disciplines/NinjaLineages_CorpseUtils"

NinjaLineages = NinjaLineages or {}
NinjaLineages.GeneExperimentationServer = NinjaLineages.GeneExperimentationServer or {}

local ServerLogic = NinjaLineages.GeneExperimentationServer
local consts = NinjaLineages.Constants.GeneExperimentation

local function notifyPlayer(player, textKey)
    if not player or not textKey then return end
    if NinjaLineages.isServer() then
        sendServerCommand(player, "NinjaLineages", "geneExperimentationMessage", {
            textKey = textKey,
            casterOnlineId = player:getOnlineID()
        })
    else
        player:Say(getText(textKey))
    end
end

-- Freshness calculation: 1..84 -> 60..100%, 85..100 -> 100%
local function rollSampleFreshness()
    local roll = ZombRand(1, 101) -- 1..100
    if roll >= consts.Extraction.PERFECT_ROLL_THRESHOLD then
        return 100
    end
    local fraction = (roll - 1) / (consts.Extraction.PERFECT_ROLL_THRESHOLD - 2) -- 0..1 across 1..84
    return math.floor(consts.Extraction.MIN_ROLL_FRESHNESS + fraction * (consts.Extraction.MAX_ROLL_FRESHNESS - consts.Extraction.MIN_ROLL_FRESHNESS) + 0.5)
end

local function applyItemFreshness(item, freshness)
    if not item then return end
    local offAgeMax = (item.getOffAgeMax and item:getOffAgeMax()) or 4
    if offAgeMax > 0 and item.setAge then
        local age = (1.0 - (freshness / 100.0)) * offAgeMax
        item:setAge(math.max(0, age))
    end
    item:getModData().freshness = freshness
end

local function getItemCurrentFreshness(item)
    if not item then return 100 end
    local offAgeMax = (item.getOffAgeMax and item:getOffAgeMax()) or 0
    local age = (item.getAge and item:getAge()) or 0
    if offAgeMax > 0 then
        if item.isRotten and item:isRotten() then return 0 end
        local remaining = math.max(0, math.min(1.0, 1.0 - (age / offAgeMax)))
        return math.floor(remaining * 100 + 0.5)
    end
    return item:getModData().freshness or 100
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

-- Server completion logic for experiments (called from singleplayer or server command handler)
function ServerLogic.completeExperiment(player, corpse, actionId)
    if not player or not corpse then return false end
    local modData = corpse:getModData()
    if modData.experimented then return false end
    
    local isZombieNinja = modData.isZombieNinja == true
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
        notifyPlayer(player, "UI_NL_GeneExperimentationUnlocked")
    
    elseif actionId == "Extract Blood Sample" then
        if not NinjaLineages.Progression.isCompleted(player, "blood_extraction") then return false end
        
        modData.experimented = true
        local item = instanceItem("Base.NL_BloodSample")
        if item then player:getInventory():AddItem(item) end
        
    elseif actionId == "Extract Ocular Tissue" then
        if not NinjaLineages.Progression.isCompleted(player, "ocular_extraction") then return false end
        
        modData.experimented = true
        local item = instanceItem("Base.NL_OcularTissueSample")
        if item then
            local eyeType = ZombRand(0, 2) == 0 and "sharingan" or "byakugan"
            local freshness = rollSampleFreshness()
            item:getModData().eyeType = eyeType
            applyItemFreshness(item, freshness)
            local typeName = eyeType == "sharingan" and getText("UI_NL_Ability_Sharingan_Name") or getText("UI_NL_Ability_Byakugan_Name")
            item:setName(getText("UI_item_NL_OcularTissueSample") .. " (" .. typeName .. ")")
            player:getInventory():AddItem(item)
        end
        
    elseif actionId == "Extract Gene Sample" then
        if not NinjaLineages.Progression.isCompleted(player, "gene_extraction") then return false end
        
        modData.experimented = true
        local item = instanceItem("Base.NL_GeneSample")
        if item then
            local freshness = rollSampleFreshness()
            applyItemFreshness(item, freshness)
            player:getInventory():AddItem(item)
        end
    else
        return false
    end
    
    NinjaLineages.transmitPlayerData(player)
    return true
end

-- ============================================================================
-- Experimental Surgery Server Handlers
-- ============================================================================

local MAX_PATIENT_DISTANCE = 2.5

local function isPatientInRange(doctor, patient)
    if not doctor or not patient or doctor:isDead() or patient:isDead() then return false end
    if doctor == patient then return true end
    if math.floor(doctor:getZ()) ~= math.floor(patient:getZ()) then return false end
    local dx = doctor:getX() - patient:getX()
    local dy = doctor:getY() - patient:getY()
    return (dx * dx + dy * dy) <= (MAX_PATIENT_DISTANCE * MAX_PATIENT_DISTANCE)
end

local function resolvePatient(doctor, patientOnlineId)
    if not doctor then return nil end
    if patientOnlineId == nil then return doctor end
    if not getPlayerByOnlineID then return nil end
    local onlineId = tonumber(patientOnlineId)
    if not onlineId then return nil end
    local patient = getPlayerByOnlineID(onlineId)
    if not isPatientInRange(doctor, patient) then return nil end
    return patient
end

local function isValidEyeSlot(eyeSlot)
    return eyeSlot == "left" or eyeSlot == "right"
end

function ServerLogic.removeEye(doctor, patient, eyeSlot)
    if not doctor or not patient or not isValidEyeSlot(eyeSlot) then return false end
    if not isPatientInRange(doctor, patient) then return false end
    if not NinjaLineages.Progression.isCompleted(doctor, "experimental_surgeries") then return false end

    NinjaLineages.initPlayerEyes(patient)
    local data = NinjaLineages.getNLData(patient)
    if not data or not data.eyes or not data.eyes[eyeSlot] then return false end

    local currentEye = data.eyes[eyeSlot]
    local eyeType = currentEye.type
    local freshness = currentEye.freshness or 100

    -- Empty slot
    data.eyes[eyeSlot] = nil

    -- Produce ocular sample if it was a special eye
    if eyeType == "sharingan" or eyeType == "byakugan" or eyeType == "rinnegan" then
        local item = instanceItem("Base.NL_OcularTissueSample")
        if item then
            item:getModData().eyeType = eyeType
            applyItemFreshness(item, freshness)
            local typeName = eyeType == "sharingan" and getText("UI_NL_Ability_Sharingan_Name")
                or (eyeType == "byakugan" and getText("UI_NL_Ability_Byakugan_Name") or getText("UI_NL_Ability_ShinraTensei_Name"))
            item:setName(getText("UI_item_NL_OcularTissueSample") .. " (" .. typeName .. ")")
            doctor:getInventory():AddItem(item)
            if NinjaLineages.isServer() then
                pcall(function() sendAddItemToContainer(doctor:getInventory(), item) end)
            end
        end
    end

    NinjaLineages.transmitPlayerData(patient)
    notifyPlayer(doctor, "UI_NL_Surgery_EyeRemovedSuccess")
    if doctor ~= patient then
        notifyPlayer(patient, "UI_NL_Surgery_EyeRemovedSuccess")
    end
    return true
end

function ServerLogic.implantEye(doctor, patient, eyeSlot, itemID)
    if not doctor or not patient or not isValidEyeSlot(eyeSlot) then return false end
    if not isPatientInRange(doctor, patient) then return false end
    if not NinjaLineages.Progression.isCompleted(doctor, "experimental_surgeries") then return false end

    NinjaLineages.initPlayerEyes(patient)
    local data = NinjaLineages.getNLData(patient)
    if not data or not data.eyes or data.eyes[eyeSlot] ~= nil then return false end

    -- Find ocular item in doctor inventory or bags
    local item = NinjaLineages.Utils.Inventory.findItem(doctor, itemID, "Base.NL_OcularTissueSample")
    if not item then return false end

    local freshness = getItemCurrentFreshness(item)
    local eyeType = item:getModData().eyeType
    if eyeType ~= "sharingan" and eyeType ~= "byakugan" and eyeType ~= "rinnegan" then
        return false
    end

    -- Consume item
    NinjaLineages.Utils.Inventory.consumeInventoryItem(doctor, item)

    -- Implant
    data.eyes[eyeSlot] = {
        type = eyeType,
        freshness = math.max(1, freshness),
    }

    NinjaLineages.transmitPlayerData(patient)
    notifyPlayer(doctor, "UI_NL_Surgery_EyeImplantedSuccess")
    if doctor ~= patient then
        notifyPlayer(patient, "UI_NL_Surgery_EyeImplantedSuccess")
    end
    return true
end

function ServerLogic.implantGenes(doctor, patient, itemID)
    if not doctor or not patient then return false end
    if not isPatientInRange(doctor, patient) then return false end
    if not NinjaLineages.Progression.isCompleted(doctor, "experimental_surgeries") then return false end

    NinjaLineages.initPlayerEyes(patient)
    local data = NinjaLineages.getNLData(patient)
    if not data then return false end

    -- Find gene sample in doctor inventory or bags
    local item = NinjaLineages.Utils.Inventory.findItem(doctor, itemID, "Base.NL_GeneSample")
    if not item then return false end

    -- Consume gene sample
    NinjaLineages.Utils.Inventory.consumeInventoryItem(doctor, item)

    local now = NinjaLineages.Utils.Time.gameMinutes()
    local rinneganAwakened = false

    -- Check rare Rinnegan awakening condition:
    -- Player must have Mangekyo Sharingan stage (>= 4) and at least 1 installed Sharingan eye
    local sharinganCount = NinjaLineages.getInstalledEyeCount(patient, "sharingan")
    if (data.sharinganStage or 0) >= 4 and sharinganCount > 0 then
        local chance = consts.Surgery.RINNEGAN_AWAKENING_CHANCE or 10
        if ZombRand(1, 101) <= chance then
            -- Convert one installed Sharingan eye into Rinnegan (preserve Mangekyo stage 4 on player)
            if data.eyes.left and data.eyes.left.type == "sharingan" then
                data.eyes.left.type = "rinnegan"
            elseif data.eyes.right and data.eyes.right.type == "sharingan" then
                data.eyes.right.type = "rinnegan"
            end
            data.rinneganUnlocked = true
            rinneganAwakened = true

            notifyPlayer(patient, "UI_NL_RinneganAwakened")
            if NinjaLineages.isServer() then
                sendServerCommand("NinjaLineages", "abilityEvent", {
                    kind = "rinnegan_awakened",
                    casterOnlineId = patient:getOnlineID(),
                })
            end
        end
    end

    -- If Rinnegan awakened, that is the exclusive experiment result (no normal gene buff/debuff)
    if not rinneganAwakened then
        -- Roll 3-day gene buff or debuff
        local isBuff = ZombRand(0, 2) == 0
        local pool = isBuff and consts.GeneEffects.Buffs or consts.GeneEffects.Debuffs
        local chosen = pool[ZombRand(1, #pool + 1)]

        if chosen then
            data.activeGeneEffect = {
                id = chosen.id,
                nameKey = chosen.nameKey,
                descKey = chosen.descKey,
                isBuff = chosen.isBuff,
                expiresAt = now + consts.Surgery.GENE_EFFECT_DURATION_MINUTES,
            }
            notifyPlayer(patient, chosen.nameKey)
        end
    end

    NinjaLineages.transmitPlayerData(patient)
    notifyPlayer(doctor, "UI_NL_Surgery_GeneImplantedSuccess")
    return true
end

-- Handle Complete Corpse Experiment
local function handleCompleteCorpseExperiment(player, args)
    local corpseId = args and args.corpse
    local actionId = args and args.actionId
    if not corpseId or not actionId then return end
    
    local corpse = NinjaLineages.CorpseUtils.getCorpseFromIdentifier(corpseId)
    if corpse then
        -- Validate player distance to corpse (within 4 tiles)
        local dx = player:getX() - corpse:getX()
        local dy = player:getY() - corpse:getY()
        if (dx * dx + dy * dy) <= 16 then
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

local function handlePerformExperimentalSurgery(doctor, args)
    if not doctor or not args then return end
    local surgeryType = args.surgeryType
    local eyeSlot = args.eyeSlot
    local itemId = args.itemId

    local patient = resolvePatient(doctor, args.patientOnlineId)
    if not patient then return end

    if surgeryType == "remove_eye" then
        ServerLogic.removeEye(doctor, patient, eyeSlot)
    elseif surgeryType == "implant_eye" then
        ServerLogic.implantEye(doctor, patient, eyeSlot, itemId)
    elseif surgeryType == "implant_genes" then
        ServerLogic.implantGenes(doctor, patient, itemId)
    end
end

function ServerLogic.transfuseBlood(doctor, patient, itemId)
    if not doctor or not patient then return false end
    if not isPatientInRange(doctor, patient) then return false end
    if not NinjaLineages.Progression.isCompleted(doctor, "blood_extraction") then
        notifyPlayer(doctor, "UI_NL_Error_NeedBloodExtraction")
        return false
    end

    local item = NinjaLineages.Utils.Inventory.findItem(doctor, itemId, "Base.NL_BloodSample")
    if not item then
        notifyPlayer(doctor, "UI_NL_Error_NoBloodSample")
        return false
    end

    local freshness = getItemCurrentFreshness(item)
    if freshness <= 0 or (item.isRotten and item:isRotten()) then
        notifyPlayer(doctor, "UI_NL_Error_RottenBloodTransfusion")
        return false
    end

    NinjaLineages.Utils.Inventory.consumeInventoryItem(doctor, item)

    -- Immediate chakra restore scaling with freshness: Balance.getCost("MAJOR") * (freshness / 100)
    local restoreAmount = NinjaLineages.Balance.getCost("MAJOR") * (freshness / 100.0)
    NinjaLineages.Chakra.addChakra(patient, restoreAmount)

    -- Temporary chakra regeneration boost: duration scales with freshness (1 game hour * (freshness / 100))
    local now = NinjaLineages.Utils.Time.gameMinutes()
    local duration = NinjaLineages.Balance.getDuration("STANDARD") * (freshness / 100.0)
    local data = NinjaLineages.getNLData(patient)
    data.bloodTransfusionRegenUntil = math.max(data.bloodTransfusionRegenUntil or 0, now + duration)

    -- Sickness roll if freshness < 100%
    if freshness < 100 then
        local sicknessChance = (100 - freshness) * 0.5
        local roll = ZombRand(1, 101)
        if roll <= sicknessChance then
            local bodyDamage = patient:getBodyDamage()
            if bodyDamage then
                local currentPoison = bodyDamage:getPoisonLevel() or 0
                bodyDamage:setPoisonLevel(math.min(100, currentPoison + (100 - freshness) * 0.4))
                local currentSickness = bodyDamage:getFoodSicknessLevel() or 0
                bodyDamage:setFoodSicknessLevel(math.min(100, currentSickness + (100 - freshness) * 0.4))
            end
            notifyPlayer(patient, "UI_NL_BloodTransfusion_Sick")
        end
    end

    NinjaLineages.transmitPlayerData(patient)
    notifyPlayer(doctor, "UI_NL_BloodTransfusion_Success")
    return true
end

local function handlePerformBloodTransfusion(doctor, args)
    if not doctor or not args then return end
    local itemId = args.itemId
    local patient = resolvePatient(doctor, args.patientOnlineId)
    if not patient then return end
    ServerLogic.transfuseBlood(doctor, patient, itemId)
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
    elseif command == "performExperimentalSurgery" then
        handlePerformExperimentalSurgery(player, args)
    elseif command == "performBloodTransfusion" then
        handlePerformBloodTransfusion(player, args)
    end
end

NinjaLineages.addEventOnce("server.geneExperimentation.onClientCommand", Events.OnClientCommand, onClientCommand)
