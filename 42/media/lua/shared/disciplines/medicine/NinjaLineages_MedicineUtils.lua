require "NinjaLineages_Balance"
require "NinjaLineages_Utils"

NinjaLineages = NinjaLineages or {}
NinjaLineages.MedicineUtils = NinjaLineages.MedicineUtils or {}

local MedicineUtils = NinjaLineages.MedicineUtils
local consts = NinjaLineages.Balance.GeneExperimentation

-- Freshness calculation: 1..84 -> 60..100%, 85..100 -> 100%
function MedicineUtils.rollSampleFreshness()
    local roll = ZombRand(1, 101) -- 1..100
    if roll >= consts.Extraction.PERFECT_ROLL_THRESHOLD then
        return consts.Extraction.MAX_ROLL_FRESHNESS
    end
    local fraction = (roll - 1) / (consts.Extraction.PERFECT_ROLL_THRESHOLD - 2) -- 0..1 across 1..84
    return math.floor(consts.Extraction.MIN_ROLL_FRESHNESS + fraction * (consts.Extraction.MAX_ROLL_FRESHNESS - consts.Extraction.MIN_ROLL_FRESHNESS) + 0.5)
end

function MedicineUtils.applyItemFreshness(item, freshness)
    if not item then return end
    local offAgeMax = (item.getOffAgeMax and item:getOffAgeMax()) or 4
    if offAgeMax > 0 and item.setAge then
        local age = (1.0 - (freshness / 100.0)) * offAgeMax
        item:setAge(math.max(0, age))
    end
    item:getModData().freshness = freshness
end

function MedicineUtils.getItemFreshness(item)
    if not item then return consts.Extraction.MAX_ROLL_FRESHNESS end
    local offAgeMax = (item.getOffAgeMax and item:getOffAgeMax()) or 0
    local age = (item.getAge and item:getAge()) or 0
    if offAgeMax > 0 then
        if item.isRotten and item:isRotten() then return 0 end
        local remaining = math.max(0, math.min(1.0, 1.0 - (age / offAgeMax)))
        return math.floor(remaining * 100 + 0.5)
    end
    return item:getModData().freshness or consts.Extraction.MAX_ROLL_FRESHNESS
end

-- Compatibility alias
MedicineUtils.getItemCurrentFreshness = MedicineUtils.getItemFreshness

function MedicineUtils.isValidEyeSlot(eyeSlot)
    return eyeSlot == "left" or eyeSlot == "right"
end

function MedicineUtils.getPatientMaxDistance()
    return NinjaLineages.Balance.getRadius(consts.Surgery.PATIENT_RANGE_TIER)
end

function MedicineUtils.isPatientInRange(doctor, patient)
    if not doctor or not patient or doctor:isDead() or patient:isDead() then return false end
    if doctor == patient then return true end
    if math.floor(doctor:getZ()) ~= math.floor(patient:getZ()) then return false end
    local maxDist = MedicineUtils.getPatientMaxDistance()
    local dx = doctor:getX() - patient:getX()
    local dy = doctor:getY() - patient:getY()
    return (dx * dx + dy * dy) <= (maxDist * maxDist)
end

function MedicineUtils.resolvePatient(doctor, patientOnlineId)
    if not doctor then return nil end
    if patientOnlineId == nil then return doctor end
    if not getPlayerByOnlineID then return nil end
    local onlineId = tonumber(patientOnlineId)
    if not onlineId then return nil end
    local patient = getPlayerByOnlineID(onlineId)
    if not MedicineUtils.isPatientInRange(doctor, patient) then return nil end
    return patient
end

function MedicineUtils.notifyPlayer(player, textKey)
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
