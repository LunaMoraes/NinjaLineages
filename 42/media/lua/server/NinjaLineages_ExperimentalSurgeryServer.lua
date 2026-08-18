require "NinjaLineages_Progression"
require "NinjaLineages_Utils"
require "NinjaLineages_Balance"
require "NinjaLineages_Traits"
require "disciplines/medicine/NinjaLineages_MedicineUtils"

NinjaLineages = NinjaLineages or {}
NinjaLineages.ExperimentalSurgeryServer = NinjaLineages.ExperimentalSurgeryServer or {}
NinjaLineages.GeneExperimentationServer = NinjaLineages.GeneExperimentationServer or {}

local SurgeryServer = NinjaLineages.ExperimentalSurgeryServer
local MedicineUtils = NinjaLineages.MedicineUtils
local consts = NinjaLineages.Balance.GeneExperimentation

function SurgeryServer.removeEye(doctor, patient, eyeSlot)
    if not doctor or not patient or not MedicineUtils.isValidEyeSlot(eyeSlot) then return false end
    if not MedicineUtils.isPatientInRange(doctor, patient) then return false end
    if not NinjaLineages.Progression.isCompleted(doctor, "experimental_surgeries") then return false end

    NinjaLineages.initPlayerEyes(patient)
    local data = NinjaLineages.getNLData(patient)
    if not data or not data.eyes or not data.eyes[eyeSlot] then return false end

    local currentEye = data.eyes[eyeSlot]
    local eyeType = currentEye.type
    local freshness = currentEye.freshness or consts.Extraction.MAX_ROLL_FRESHNESS

    -- Empty slot
    data.eyes[eyeSlot] = nil

    -- Produce ocular sample if it was a special eye
    if eyeType == "sharingan" or eyeType == "byakugan" or eyeType == "rinnegan" then
        local item = instanceItem("Base.NL_OcularTissueSample")
        if item then
            item:getModData().eyeType = eyeType
            MedicineUtils.applyItemFreshness(item, freshness)
            local typeName = eyeType == "sharingan" and getText("UI_NL_Ability_Sharingan_Name")
                or (eyeType == "byakugan" and getText("UI_NL_Ability_Byakugan_Name") or getText("UI_NL_Eye_Rinnegan"))
            item:setName(getText("UI_item_NL_OcularTissueSample") .. " (" .. typeName .. ")")
            doctor:getInventory():AddItem(item)
            if NinjaLineages.isServer() then
                pcall(function() sendAddItemToContainer(doctor:getInventory(), item) end)
            end
        end
    end

    NinjaLineages.transmitPlayerData(patient)
    MedicineUtils.notifyPlayer(doctor, "UI_NL_Surgery_EyeRemovedSuccess")
    if doctor ~= patient then
        MedicineUtils.notifyPlayer(patient, "UI_NL_Surgery_EyeRemovedSuccess")
    end
    return true
end

function SurgeryServer.implantEye(doctor, patient, eyeSlot, itemID)
    if not doctor or not patient or not MedicineUtils.isValidEyeSlot(eyeSlot) then return false end
    if not MedicineUtils.isPatientInRange(doctor, patient) then return false end
    if not NinjaLineages.Progression.isCompleted(doctor, "experimental_surgeries") then return false end

    NinjaLineages.initPlayerEyes(patient)
    local data = NinjaLineages.getNLData(patient)
    if not data or not data.eyes or data.eyes[eyeSlot] ~= nil then return false end

    -- Find ocular item in doctor inventory or bags
    local item = NinjaLineages.Utils.Inventory.findItem(doctor, itemID, "Base.NL_OcularTissueSample")
    if not item then return false end

    local freshness = MedicineUtils.getItemFreshness(item)
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
    MedicineUtils.notifyPlayer(doctor, "UI_NL_Surgery_EyeImplantedSuccess")
    if doctor ~= patient then
        MedicineUtils.notifyPlayer(patient, "UI_NL_Surgery_EyeImplantedSuccess")
    end
    return true
end

function SurgeryServer.implantGenes(doctor, patient, itemID)
    if not doctor or not patient then return false end
    if not MedicineUtils.isPatientInRange(doctor, patient) then return false end
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
        local chance = consts.Surgery.RINNEGAN_AWAKENING_CHANCE
        if ZombRand(1, 101) <= chance then
            -- Convert one installed Sharingan eye into Rinnegan (preserve Mangekyo stage 4 on player)
            if data.eyes.left and data.eyes.left.type == "sharingan" then
                data.eyes.left.type = "rinnegan"
            elseif data.eyes.right and data.eyes.right.type == "sharingan" then
                data.eyes.right.type = "rinnegan"
            end
            data.rinneganUnlocked = true
            rinneganAwakened = true

            MedicineUtils.notifyPlayer(patient, "UI_NL_RinneganAwakened")
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
            MedicineUtils.notifyPlayer(patient, chosen.nameKey)
        end
    end

    NinjaLineages.transmitPlayerData(patient)
    MedicineUtils.notifyPlayer(doctor, "UI_NL_Surgery_GeneImplantedSuccess")
    return true
end

function SurgeryServer.transfuseBlood(doctor, patient, itemId)
    if not doctor or not patient then return false end
    if not MedicineUtils.isPatientInRange(doctor, patient) then return false end
    if not NinjaLineages.Progression.isCompleted(doctor, "blood_extraction") then
        MedicineUtils.notifyPlayer(doctor, "UI_NL_Error_NeedBloodExtraction")
        return false
    end

    local item = NinjaLineages.Utils.Inventory.findItem(doctor, itemId, "Base.NL_BloodSample")
    if not item then
        MedicineUtils.notifyPlayer(doctor, "UI_NL_Error_NoBloodSample")
        return false
    end

    local freshness = MedicineUtils.getItemFreshness(item)
    if freshness <= 0 or (item.isRotten and item:isRotten()) then
        MedicineUtils.notifyPlayer(doctor, "UI_NL_Error_RottenBloodTransfusion")
        return false
    end

    NinjaLineages.Utils.Inventory.consumeInventoryItem(doctor, item)

    local transfusion = consts.BloodTransfusion
    local percentMaximum = NinjaLineages.Balance.Progression.PercentScale
    local restoreAmount = NinjaLineages.Balance.getCost(transfusion.CHAKRA_RESTORE_COST_TIER)
        * (freshness / percentMaximum)
    NinjaLineages.Chakra.addChakra(patient, restoreAmount)

    -- Temporary chakra regeneration boost: six in-game minutes at full freshness.
    local now = NinjaLineages.Utils.Time.gameMinutes()
    local duration = NinjaLineages.Balance.getDuration(transfusion.REGEN_DURATION_TIER)
        * (freshness / percentMaximum)
    local data = NinjaLineages.getNLData(patient)
    data.bloodTransfusionRegenUntil = math.max(data.bloodTransfusionRegenUntil or 0, now + duration)

    -- Sickness roll if freshness < 100%
    if freshness < percentMaximum then
        local missingFreshness = percentMaximum - freshness
        local sicknessChance = missingFreshness
            * transfusion.SICKNESS_CHANCE_PER_MISSING_FRESHNESS
        local roll = ZombRand(1, 101)
        if roll <= sicknessChance then
            local bodyDamage = patient:getBodyDamage()
            if bodyDamage then
                local currentPoison = bodyDamage:getPoisonLevel() or 0
                bodyDamage:setPoisonLevel(math.min(
                    percentMaximum,
                    currentPoison
                        + missingFreshness * transfusion.SICKNESS_SEVERITY_PER_MISSING_FRESHNESS
                ))
                local currentSickness = bodyDamage:getFoodSicknessLevel() or 0
                bodyDamage:setFoodSicknessLevel(math.min(
                    percentMaximum,
                    currentSickness
                        + missingFreshness * transfusion.SICKNESS_SEVERITY_PER_MISSING_FRESHNESS
                ))
            end
            MedicineUtils.notifyPlayer(patient, "UI_NL_BloodTransfusion_Sick")
        end
    end

    NinjaLineages.transmitPlayerData(patient)
    MedicineUtils.notifyPlayer(doctor, "UI_NL_BloodTransfusion_Success")
    return true
end

-- Backward compatibility aliases
NinjaLineages.GeneExperimentationServer.removeEye = SurgeryServer.removeEye
NinjaLineages.GeneExperimentationServer.implantEye = SurgeryServer.implantEye
NinjaLineages.GeneExperimentationServer.implantGenes = SurgeryServer.implantGenes
NinjaLineages.GeneExperimentationServer.transfuseBlood = SurgeryServer.transfuseBlood

local function handlePerformExperimentalSurgery(doctor, args)
    if not doctor or not args then return end
    local surgeryType = args.surgeryType
    local eyeSlot = args.eyeSlot
    local itemId = args.itemId

    local patient = MedicineUtils.resolvePatient(doctor, args.patientOnlineId)
    if not patient then return end

    if surgeryType == "remove_eye" then
        SurgeryServer.removeEye(doctor, patient, eyeSlot)
    elseif surgeryType == "implant_eye" then
        SurgeryServer.implantEye(doctor, patient, eyeSlot, itemId)
    elseif surgeryType == "implant_genes" then
        SurgeryServer.implantGenes(doctor, patient, itemId)
    end
end

local function handlePerformBloodTransfusion(doctor, args)
    if not doctor or not args then return end
    local itemId = args.itemId
    local patient = MedicineUtils.resolvePatient(doctor, args.patientOnlineId)
    if not patient then return end
    SurgeryServer.transfuseBlood(doctor, patient, itemId)
end

-- Client Command Router for Surgery and Transfusion
local function onClientCommand(module, command, player, args)
    if module ~= "NinjaLineages" then return end

    if command == "performExperimentalSurgery" then
        handlePerformExperimentalSurgery(player, args)
    elseif command == "performBloodTransfusion" then
        handlePerformBloodTransfusion(player, args)
    end
end

NinjaLineages.addEventOnce("server.experimentalSurgery.onClientCommand", Events.OnClientCommand, onClientCommand)
